//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 23/09/2024.
//

import Foundation
import Combine
#if canImport(AdServices)
import AdServices
#endif

final class AttributionPoster {
  /// Hard cap on attempts across launches. Apple's attribution endpoint can be
  /// unhealthy for short periods around install, so we want enough retries to
  /// survive that, but not so many that we keep hammering it for users who
  /// will never have attribution data.
  static let maxAttempts = 8

  /// Maximum window from the first attempt during which we'll keep retrying.
  /// Apple's docs say the attribution token is valid for 24h after it's
  /// generated and that posts should happen within that window. We generate
  /// a fresh token on every attempt, but the first attempt's clock is what
  /// bounds Apple's install-side attribution data — past 24h, even a fresh
  /// token won't resolve to a campaign.
  static let maxRetryWindow: TimeInterval = 24 * 60 * 60

  /// In-session retry plan for transient errors from `AAAttribution.attributionToken()`,
  /// which can throw `networkError` if called too soon after launch. The HTTP
  /// post to our backend is already covered by `Task.retrying` inside
  /// `CustomURLSession`, so we don't add an outer backoff there.
  private static let tokenFetchBackoff: [TimeInterval] = [2, 6, 15]

  private let stateQueue = DispatchQueue(label: "com.superwall.attributionposter.state")
  private var isCollecting = false
  private var currentTask: Task<Void, Never>?
  /// Monotonic generation stamped onto each outer call that claims the slot.
  /// `cancelInFlight` bumps this so a late-completing call's `defer` won't
  /// clobber the state belonging to a newly started call.
  private var ownerGeneration: UInt64 = 0

  private unowned let storage: Storage
  private unowned let network: Network
  private unowned let configManager: ConfigManager
  private unowned let attributionFetcher: AttributionFetcher
  private var cancellables: [AnyCancellable] = []

  init(
    storage: Storage,
    network: Network,
    configManager: ConfigManager,
    attributionFetcher: AttributionFetcher
  ) {
    self.storage = storage
    self.network = network
    self.configManager = configManager
    self.attributionFetcher = attributionFetcher

    if #available(iOS 14.3, *) {
      listenToConfig()
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillEnterForeground),
      name: SystemInfo.applicationWillEnterForegroundNotification,
      object: nil
    )
  }

  @available(iOS 14.3, *)
  private func listenToConfig() {
    // Track the enabled flag across config refreshes. `removeDuplicates` has
    // to see the toggles to detect a transition, so we dedup on the bool
    // *before* filtering. This fires once when the flag first becomes true,
    // and again if it goes true → false → true mid-session.
    configManager.configState
      .compactMap { $0.getConfig() }
      .map { $0.attribution?.appleSearchAds?.enabled == true }
      .removeDuplicates()
      .filter { $0 }
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { [weak self] _ in
          // Match applicationWillEnterForeground's priority: default-priority
          // tasks can be deferred under load, and attribution is bounded by
          // Apple's 24h install window.
          Task(priority: .utility) {
            await self?.getAdServicesTokenIfNeeded()
          }
        }
      )
      .store(in: &cancellables)
  }

  @objc
  private func applicationWillEnterForeground() {
    #if os(iOS) || os(macOS) || os(visionOS)
    guard Superwall.isInitialized else {
      return
    }

    // .utility rather than .background — background-priority tasks can be
    // deferred indefinitely under load, but the attribution token is only
    // useful within ~24h of install.
    Task(priority: .utility) {
      if #available(iOS 14.3, macOS 11.1, macCatalyst 14.3, *) {
        await getAdServicesTokenIfNeeded()
      }
    }
    #endif
  }

  /// Re-applies the cached ASA attribution dict to the current user's
  /// attributes. Called from `reset(duringIdentify:)` after user files are
  /// wiped so the new user identity inherits the install-scoped campaign
  /// keys without us re-hitting Apple. No-op if nothing was ever fetched.
  func reapplyCachedAttribution() {
    guard let cached = storage.get(AdServicesAttributionDataStorage.self) else {
      return
    }
    let attribution = convertJSONToDictionary(attribution: cached)
    if attribution.isEmpty {
      return
    }
    Superwall.shared.setUserAttributes(attribution)
  }

  /// Cancel any in-flight attempt. Used during reset so we don't race a
  /// completing post against the new user's state.
  func cancelInFlight() {
    stateQueue.sync {
      currentTask?.cancel()
      currentTask = nil
      isCollecting = false
      // Invalidate the in-flight outer call's ownership so its `defer`
      // becomes a no-op once it unblocks from `await task.value` — otherwise
      // it would clobber state belonging to a newly started call.
      ownerGeneration &+= 1
    }
  }

  // Should match OS availability in https://developer.apple.com/documentation/ad_services
  @available(iOS 14.3, tvOS 14.3, watchOS 6.2, macOS 11.1, macCatalyst 14.3, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  func getAdServicesTokenIfNeeded() async {
    // Single-flight: only one collection at a time. Synchronous check on the
    // state queue avoids the TOCTOU race in the previous implementation.
    // The generation stamp lets the cleanup `defer` detect whether we still
    // own the slot when we unblock — `cancelInFlight` may have released it
    // and a new call may have already claimed it.
    let myGeneration: UInt64? = stateQueue.sync {
      if isCollecting {
        return nil
      }
      isCollecting = true
      ownerGeneration &+= 1
      return ownerGeneration
    }
    guard let myGeneration = myGeneration else {
      return
    }
    defer {
      stateQueue.sync {
        guard ownerGeneration == myGeneration else {
          return
        }
        isCollecting = false
        currentTask = nil
      }
    }

    let attempts = storage.get(AdServicesAttributionAttemptsStorage.self)
    guard canStartAttempt(currentAttempts: attempts) else {
      return
    }

    await Superwall.shared.track(InternalSuperwallEvent.AdServicesTokenRetrieval(state: .start))

    // Re-check ownership, then create and store the task atomically inside
    // the queue. `cancelInFlight()` may have fired while we were suspended
    // on the track call above (before `currentTask` was ever stored), in
    // which case our pre-reset `existingAttempts` snapshot is now stale and
    // running runAttempt would clobber the new user's freshly reset storage.
    // Doing the create+store inside the same sync block also prevents
    // cancelInFlight from running between Task creation and storage, which
    // would otherwise leave the task uncancellable from the outside.
    let task: Task<Void, Never>? = stateQueue.sync {
      guard ownerGeneration == myGeneration else {
        return nil
      }
      let task = Task<Void, Never> { [weak self] in
        await self?.runAttempt(existingAttempts: attempts)
      }
      currentTask = task
      return task
    }
    guard let task = task else {
      return
    }
    await task.value
  }

  /// Storage and config guards that decide whether it's worth starting a
  /// fresh attempt. Pulled out of `getAdServicesTokenIfNeeded` so the main
  /// flow stays under the cyclomatic-complexity budget.
  private func canStartAttempt(currentAttempts: AdServicesAttributionAttempts?) -> Bool {
    // Already successfully posted for this install.
    if storage.get(AdServicesTokenStorage.self) != nil {
      return false
    }
    // This device permanently can't provide an attribution token (missing
    // entitlement, unsupported platform). Stop retrying.
    if storage.get(AdServicesAttributionUnsupportedStorage.self) == true {
      return false
    }
    guard configManager.config?.attribution?.appleSearchAds?.enabled == true else {
      return false
    }
    if let attempts = currentAttempts {
      if attempts.count >= Self.maxAttempts {
        return false
      }
      if Date().timeIntervalSince(attempts.firstAttemptDate) > Self.maxRetryWindow {
        return false
      }
    }
    return true
  }

  @available(iOS 14.3, macOS 11.1, macCatalyst 14.3, *)
  private func runAttempt(existingAttempts: AdServicesAttributionAttempts?) async {
    let token: String
    do {
      token = try await fetchTokenWithBackoff()
    } catch is CancellationError {
      // Cancellation means `cancelInFlight` (typically via reset) asked us to
      // abandon — not a real failure. Don't bookkeep an attempt, especially
      // because storage may have just been wiped and `existingAttempts` is
      // stale; writing it would inflate the new user's attempt count.
      return
    } catch let error as PosterError where error == .permanentlyUnsupported {
      // Don't burn the attempt budget on a device that will never have a
      // token, but do persist a sentinel so subsequent launches short-circuit
      // instead of repeating the doomed SDK call indefinitely.
      storage.save(true, forType: AdServicesAttributionUnsupportedStorage.self)
      await Superwall.shared.track(
        InternalSuperwallEvent.AdServicesTokenRetrieval(state: .fail(error))
      )
      return
    } catch {
      recordFailedAttempt(existing: existingAttempts)
      await Superwall.shared.track(
        InternalSuperwallEvent.AdServicesTokenRetrieval(state: .fail(error))
      )
      return
    }

    if Task.isCancelled {
      return
    }

    await Superwall.shared.track(
      InternalSuperwallEvent.AdServicesTokenRetrieval(state: .complete(token))
    )

    do {
      // CustomURLSession already wraps the request in Task.retrying (3
      // attempts × 5s for the AdServices endpoint, see Endpoint.swift), so
      // we don't need our own outer backoff here. Backend error responses
      // come back as non-2xx and are thrown by Task.retrying — they end up
      // in the catch below and bump the cross-launch attempt budget.
      let response = try await network.sendToken(token)
      if Task.isCancelled {
        return
      }
      storage.save(token, forType: AdServicesTokenStorage.self)
      storage.save(response.attribution, forType: AdServicesAttributionDataStorage.self)
      storage.delete(AdServicesAttributionAttemptsStorage.self)

      let attribution = convertJSONToDictionary(attribution: response.attribution)
      if !attribution.isEmpty {
        Superwall.shared.setUserAttributes(attribution)
      }
    } catch is CancellationError {
      return
    } catch {
      recordFailedAttempt(existing: existingAttempts)
      await Superwall.shared.track(
        InternalSuperwallEvent.AdServicesTokenRetrieval(state: .fail(error))
      )
    }
  }

  /// Retrieves the token from Apple's AdServices framework, retrying transient
  /// errors a few times in-session. `AAAttribution.attributionToken()` can
  /// throw `networkError` very early in the app's lifecycle even though the
  /// next call milliseconds later would succeed.
  @available(iOS 14.3, macOS 11.1, macCatalyst 14.3, *)
  private func fetchTokenWithBackoff() async throws -> String {
    var lastError: Error?
    for delay in [0.0] + Self.tokenFetchBackoff {
      if delay > 0 {
        // Propagate cancellation from the sleep itself — using `try?` would
        // swallow CancellationError and force callers waiting up to 15s for
        // the next post-sleep `Task.isCancelled` check to notice.
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
      if Task.isCancelled {
        throw CancellationError()
      }
      do {
        if let token = try await attributionFetcher.adServicesToken {
          return token
        }
        throw PosterError.tokenUnavailable
      } catch {
        if Self.isPermanentTokenError(error) {
          throw PosterError.permanentlyUnsupported
        }
        lastError = error
      }
    }
    throw lastError ?? PosterError.tokenUnavailable
  }

  private func recordFailedAttempt(existing: AdServicesAttributionAttempts?) {
    let now = Date()
    let updated: AdServicesAttributionAttempts
    if let existing = existing {
      updated = AdServicesAttributionAttempts(
        count: existing.count + 1,
        firstAttemptDate: existing.firstAttemptDate,
        lastAttemptDate: now
      )
    } else {
      updated = AdServicesAttributionAttempts(
        count: 1,
        firstAttemptDate: now,
        lastAttemptDate: now
      )
    }
    storage.save(updated, forType: AdServicesAttributionAttemptsStorage.self)
  }
}

private enum PosterError: Error, Equatable {
  case tokenUnavailable
  case permanentlyUnsupported
}

extension AttributionPoster {
  /// AdServices.framework error code for `platformNotSupported`. From
  /// Apple's `AAAttribution.h`:
  ///
  ///     AAAttributionErrorCodeNetworkError = 1,         // transient
  ///     AAAttributionErrorCodeInternalError = 2,        // transient
  ///     AAAttributionErrorCodePlatformNotSupported = 3, // permanent
  ///
  /// `NS_ERROR_ENUM` doesn't reliably import as a Swift symbol across SDK
  /// versions, so we match on the raw code with the constant clearly named.
  private static let platformNotSupportedCode = 3

  private static func isPermanentTokenError(_ error: Error) -> Bool {
    // Only `platformNotSupported` is permanent — this OS/app config will
    // never produce a token. `networkError` and `internalError` are both
    // transient and should keep retrying within the per-install budget.
    let nsError = error as NSError
    guard nsError.domain == "AAAttributionErrorDomain" else {
      return false
    }
    return nsError.code == platformNotSupportedCode
  }
}
