//
//  MMPAttributionManager.swift
//  SuperwallKit
//

import Foundation
import Combine

/// Thrown by `Network.matchMMPInstall(...)` when the dependencies needed to
/// build the request aren't available yet. Distinct from a transport failure
/// so the manager can skip silently without tracking a failed match.
enum MMPMatchError: Error {
  case dependenciesUnavailable
  case unsupportedPlatform
  /// The app turned off event tracking while the match was being prepared.
  case trackingDisabled
}

/// Owns the MMP (mobile measurement partner) install-attribution flow: firing
/// the match, persisting and re-applying the resolved install-scoped
/// `acquisition_*` attributes, and tracking the outcome.
///
/// `Network` is used purely as transport — it builds and sends the request and
/// returns the decoded response. Everything attribution-specific lives here,
/// mirroring how `AttributionPoster` owns the Apple Search Ads flow.
final class MMPAttributionManager {
  // The install-matching backend currently accepts only iOS and Android.
  // Do not send native Mac installs into the iOS attribution pool.
  #if os(macOS)
  static let isSupported = false
  #else
  static let isSupported = true
  #endif

  private unowned let network: Network
  private unowned let storage: Storage
  private unowned let identityManager: IdentityManager
  private unowned let configManager: ConfigManager
  private var pendingMatch: AnyCancellable?
  private let lock = NSLock()
  private var startMatch: (() -> Task<Void, Never>?)?
  private var hasStartedMatch = false
  /// Set when the running match stopped because the app opted out of tracking,
  /// so it can start again once that match has finished.
  private var didStopForOptOut = false
  /// `true` from when this launch's install match is set up until it finishes
  /// or is skipped.
  private let isMatchPending = CurrentValueSubject<Bool, Never>(false)

  /// How long a paywall waits for an install match that's still running.
  static let presentationWaitTimeout: TimeInterval = 2

  init(
    network: Network,
    storage: Storage,
    identityManager: IdentityManager,
    configManager: ConfigManager
  ) {
    self.network = network
    self.storage = storage
    self.identityManager = identityManager
    self.configManager = configManager
  }

  /// Marks this launch's install match as pending, so a paywall that's
  /// requested before the match is set up still waits for it.
  func markMatchPending() {
    isMatchPending.send(Self.isSupported)
  }

  /// Calls `startMatch` once config says the MMP is enabled for this app,
  /// which may be straight away if config is already loaded. It's off by
  /// default, so it never fires if the backend doesn't turn it on. Works the
  /// same way `AttributionPoster` waits for Apple Search Ads to be enabled.
  ///
  /// `startMatch` returns the running match, or `nil` if it skipped it
  /// because the app has opted out of tracking. A skipped match is tried
  /// again when the app opts back in, via `startMatchIfEnabled()`.
  func matchInstallOnceEnabled(_ startMatch: @escaping () -> Task<Void, Never>?) {
    guard Self.isSupported else { return }
    lock.lock()
    self.startMatch = startMatch
    lock.unlock()
    isMatchPending.send(true)

    pendingMatch = configManager.configState
      .compactMap { $0.getConfig() }
      .map { $0.attribution?.mmp?.enabled == true }
      .removeDuplicates()
      .filter { $0 }
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { [weak self] _ in
          self?.startMatchIfEnabled()
        }
      )
  }

  /// Starts this launch's install match if config has the MMP on and it
  /// hasn't started yet. Called when config arrives and when the app turns
  /// tracking back on.
  func startMatchIfEnabled() {
    if configManager.config?.attribution?.mmp?.enabled != true {
      return
    }
    lock.lock()
    defer { lock.unlock() }
    if hasStartedMatch {
      return
    }
    startMatchWhileLocked()
  }

  /// Starts the match, or ends its pending state if the app is opted out.
  /// Call with `lock` held.
  private func startMatchWhileLocked() {
    guard let startMatch = startMatch else {
      return
    }
    guard let match = startMatch() else {
      // Skipped while opted out. Don't hold paywalls up in the meantime.
      isMatchPending.send(false)
      return
    }
    hasStartedMatch = true
    isMatchPending.send(true)
    Task { [weak self] in
      await match.value
      self?.finishMatch()
    }
  }

  /// Marks the running match as stopped by an opt-out, so it can start again
  /// when it finishes.
  private func stopMatchForOptOut() {
    lock.lock()
    didStopForOptOut = true
    lock.unlock()
  }

  /// Ends the running match. One stopped by an opt-out starts again straight
  /// away if the app has already opted back in, since that opt-in found it
  /// still running, and the next opt-in starts it otherwise. A restart keeps
  /// the pending state on throughout, so waiting paywalls keep waiting for it.
  private func finishMatch() {
    lock.lock()
    defer { lock.unlock() }
    if didStopForOptOut {
      didStopForOptOut = false
      hasStartedMatch = false
      if configManager.config?.attribution?.mmp?.enabled == true {
        startMatchWhileLocked()
        return
      }
    }
    isMatchPending.send(false)
  }

  /// On a first launch, a paywall can be requested while the install match is
  /// still running. If the MMP is on and the placement's audiences use
  /// `acquisition_*` attributes, this waits for the match, up to `timeout`, so
  /// they're there when the audiences are checked. Returns straight away
  /// otherwise.
  func waitForPendingMatch(
    ifUsedBy trigger: Trigger?,
    timeout: TimeInterval = presentationWaitTimeout
  ) async {
    guard let trigger = trigger else {
      return
    }
    if !isMatchPending.value {
      return
    }
    if configManager.config?.attribution?.mmp?.enabled != true {
      return
    }
    if !Self.usesAcquisitionAttributes(trigger) {
      return
    }

    let isMatchPending = isMatchPending
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        _ = try? await isMatchPending.first { !$0 }.throwableAsync()
      }
      group.addTask {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
      }
      await group.next()
      group.cancelAll()
    }
  }

  static func usesAcquisitionAttributes(_ trigger: Trigger) -> Bool {
    return trigger.audiences.contains { audience in
      audience.expression?.contains("acquisition_") == true
    }
  }

  /// Fires the install-attribution match and applies its result.
  ///
  /// On a successful response the resolved `acquisition_*` payload is cached
  /// (install-scoped, so it survives `reset`) and merged into the current
  /// user's attributes. Returns whether the request completed — the caller
  /// uses this to persist the completion flag so the match isn't repeated.
  func matchInstall(
    idfa: String?,
    advertiserTrackingEnabled: Bool,
    applicationTrackingEnabled: Bool
  ) async -> Bool {
    do {
      let response = try await network.matchMMPInstall(
        idfa: idfa,
        advertiserTrackingEnabled: advertiserTrackingEnabled,
        applicationTrackingEnabled: applicationTrackingEnabled
      )

      if let acquisitionAttributes = response.acquisitionAttributes {
        // Cache the resolved payload (install-scoped) so a reset can hand it
        // to the new user without re-matching against the backend.
        storage.save(acquisitionAttributes, forType: MMPAcquisitionDataStorage.self)
        mergeAcquisitionAttributesIfNeeded(acquisitionAttributes)
      }

      await Superwall.shared.track(
        InternalSuperwallEvent.AttributionMatch(
          info: AttributionMatchInfo(
            provider: .mmp,
            matched: response.matched,
            source: response.acquisitionAttributes?["acquisition_source"]?.string ?? response.network,
            confidence: response.confidence,
            matchScore: response.matchScore,
            reason: response.breakdown?["reason"]?.string
          )
        )
      )

      // A successful response means the request was processed, even if no
      // attribution match was found.
      return true
    } catch MMPMatchError.dependenciesUnavailable, MMPMatchError.unsupportedPlatform {
      // Defensive path — `Network` already logged the skip and there's nothing
      // to track.
      return false
    } catch MMPMatchError.trackingDisabled {
      // Like a match skipped before it started, it's tried again if the app
      // opts back in.
      stopMatchForOptOut()
      return false
    } catch {
      await Superwall.shared.track(
        InternalSuperwallEvent.AttributionMatch(
          info: AttributionMatchInfo(
            provider: .mmp,
            matched: false,
            reason: "request_failed"
          )
        )
      )
      return false
    }
  }

  /// The cached MMP `acquisition_*` payload, as user attributes. It's
  /// install-scoped, so a reset hands it to the new user without re-matching
  /// against the backend, which only succeeds within the 7-day install
  /// window. Empty if no match ever resolved.
  func cachedAcquisitionAttributes() -> [String: Any] {
    guard let cached = storage.get(MMPAcquisitionDataStorage.self) else {
      return [:]
    }
    return convertJSONToDictionary(attribution: cached)
  }

  private func mergeAcquisitionAttributesIfNeeded(_ acquisitionAttributes: [String: JSON]) {
    let attributes = convertJSONToDictionary(attribution: acquisitionAttributes)
    guard !attributes.isEmpty else {
      return
    }

    let currentAttributes = identityManager.userAttributes
    let hasChanges = attributes.contains { key, value in
      guard let currentValue = currentAttributes[key] else {
        return true
      }

      return String(describing: currentValue) != String(describing: value)
    }

    guard hasChanges else {
      return
    }

    Superwall.shared.setUserAttributes(attributes)
  }
}
