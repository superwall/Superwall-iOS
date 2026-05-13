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
  private static let maxAttempts = 8

  /// Maximum window from the first attempt during which we'll keep retrying.
  /// Apple's attribution data is only useful within ~24h of install, so 48h
  /// gives generous slack for the very-first launch happening late in the
  /// window without continuing indefinitely.
  private static let maxRetryWindow: TimeInterval = 48 * 60 * 60

  /// In-session retry plan for transient errors at the SDK or network layer.
  /// Backoff grows so a single bad-network pocket doesn't burn through the
  /// per-install attempt budget.
  private static let inSessionBackoff: [TimeInterval] = [2, 6, 15]

  private let stateQueue = DispatchQueue(label: "com.superwall.attributionposter.state")
  private var isCollecting = false
  private var currentTask: Task<Void, Never>?

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
    // Don't use `.first` here: if the dashboard flips Apple Search Ads from
    // disabled to enabled mid-session we still want to react.
    configManager.configState
      .compactMap { $0.getConfig() }
      .filter { $0.attribution?.appleSearchAds?.enabled == true }
      .removeDuplicates { _, _ in true } // only trigger once per process
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { [weak self] _ in
          Task { [weak self] in
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

  /// Cancel any in-flight attempt. Used during reset so we don't race a
  /// completing post against the new user's state.
  func cancelInFlight() {
    stateQueue.sync {
      currentTask?.cancel()
      currentTask = nil
      isCollecting = false
    }
  }

  // Should match OS availability in https://developer.apple.com/documentation/ad_services
  @available(iOS 14.3, tvOS 14.3, watchOS 6.2, macOS 11.1, macCatalyst 14.3, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  func getAdServicesTokenIfNeeded() async {
    // Single-flight: only one collection at a time. Synchronous check on the
    // state queue avoids the TOCTOU race in the previous implementation.
    let shouldStart: Bool = stateQueue.sync {
      if isCollecting {
        return false
      }
      isCollecting = true
      return true
    }
    guard shouldStart else {
      return
    }
    defer {
      stateQueue.sync {
        isCollecting = false
        currentTask = nil
      }
    }

    // Already successfully posted for this install.
    if storage.get(AdServicesTokenStorage.self) != nil {
      return
    }

    guard configManager.config?.attribution?.appleSearchAds?.enabled == true else {
      return
    }

    let attempts = storage.get(AdServicesAttributionAttemptsStorage.self)
    if let attempts = attempts {
      if attempts.count >= Self.maxAttempts {
        return
      }
      if Date().timeIntervalSince(attempts.firstAttemptDate) > Self.maxRetryWindow {
        return
      }
    }

    await Superwall.shared.track(InternalSuperwallEvent.AdServicesTokenRetrieval(state: .start))

    let task = Task<Void, Never> { [weak self] in
      await self?.runAttempt(existingAttempts: attempts)
    }
    stateQueue.sync {
      currentTask = task
    }
    await task.value
  }

  @available(iOS 14.3, macOS 11.1, macCatalyst 14.3, *)
  private func runAttempt(existingAttempts: AdServicesAttributionAttempts?) async {
    let token: String
    do {
      token = try await fetchTokenWithBackoff()
    } catch let error as PosterError where error == .permanentlyUnsupported {
      // Don't burn the attempt budget on a device that will never have a token.
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
      let response = try await postTokenWithBackoff(token: token)
      if Task.isCancelled {
        return
      }
      // The backend can explicitly tell us this user wasn't from Search Ads —
      // treat that the same as success so we stop retrying.
      let attribution = convertJSONToDictionary(attribution: response.attribution)
      storage.save(token, forType: AdServicesTokenStorage.self)
      storage.delete(AdServicesAttributionAttemptsStorage.self)

      if !attribution.isEmpty {
        Superwall.shared.setUserAttributes(attribution)
      }
    } catch {
      recordFailedAttempt(existing: existingAttempts)
    }
  }

  /// Retrieves the token from Apple's AdServices framework, retrying transient
  /// errors a few times in-session. `AAAttribution.attributionToken()` can
  /// throw `networkError` very early in the app's lifecycle even though the
  /// next call milliseconds later would succeed.
  @available(iOS 14.3, macOS 11.1, macCatalyst 14.3, *)
  private func fetchTokenWithBackoff() async throws -> String {
    var lastError: Error?
    for delay in [0.0] + Self.inSessionBackoff {
      if delay > 0 {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
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

  /// Sends the token to our backend, retrying transient failures with
  /// backoff. `CustomURLSession` already retries the HTTP call internally —
  /// these retries cover the case where every internal retry fails but a
  /// short pause yields a different result (e.g. Apple's attribution endpoint
  /// catching up post-install).
  private func postTokenWithBackoff(token: String) async throws -> AdServicesResponse {
    var lastError: Error?
    for delay in [0.0] + Self.inSessionBackoff {
      if delay > 0 {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
      if Task.isCancelled {
        throw CancellationError()
      }
      do {
        return try await network.sendToken(token)
      } catch {
        lastError = error
      }
    }
    throw lastError ?? NetworkError.unknown
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

  private static func isPermanentTokenError(_ error: Error) -> Bool {
    // AAAttributionErrorCode is not consistently exposed as a typed enum
    // across SDK versions, so match on the NSError domain/code numerically.
    // Codes 2 (.platformNotSupported) and 3 (.attributionUnsupported) are
    // permanent on this device; the rest are treated as transient.
    let nsError = error as NSError
    guard nsError.domain == "AAAttributionErrorDomain" else {
      return false
    }
    return nsError.code == 2 || nsError.code == 3
  }

  private enum PosterError: Error, Equatable {
    case tokenUnavailable
    case permanentlyUnsupported
  }
}
