//
//  MMPAttributionManager.swift
//  SuperwallKit
//

import Foundation

/// Thrown by `Network.matchMMPInstall(...)` when the dependencies needed to
/// build the request aren't available yet. Distinct from a transport failure
/// so the manager can skip silently without tracking a failed match.
enum MMPMatchError: Error {
  case dependenciesUnavailable
}

/// Owns the MMP (mobile measurement partner) install-attribution flow: firing
/// the match, persisting and re-applying the resolved install-scoped
/// `acquisition_*` attributes, and tracking the outcome.
///
/// `Network` is used purely as transport — it builds and sends the request and
/// returns the decoded response. Everything attribution-specific lives here,
/// mirroring how `AttributionPoster` owns the Apple Search Ads flow.
final class MMPAttributionManager {
  private unowned let network: Network
  private unowned let storage: Storage
  private unowned let identityManager: IdentityManager

  init(
    network: Network,
    storage: Storage,
    identityManager: IdentityManager
  ) {
    self.network = network
    self.storage = storage
    self.identityManager = identityManager
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
        // Cache the resolved payload (install-scoped) so it can be re-applied
        // to a new user's attributes after `reset(duringIdentify:)` without
        // re-matching against the backend.
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
    } catch MMPMatchError.dependenciesUnavailable {
      // Defensive path — `Network` already logged the skip and there's nothing
      // to track.
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

  /// Re-applies the cached MMP `acquisition_*` payload to the current user's
  /// attributes. Called from `reset(duringIdentify:)` after user files are
  /// wiped so the new user identity inherits the install-scoped attribution
  /// without re-matching against the backend (which only succeeds within the
  /// 7-day install window). No-op if no match ever resolved.
  func reapplyCachedAcquisitionAttributes() {
    guard let cached = storage.get(MMPAcquisitionDataStorage.self) else {
      return
    }
    mergeAcquisitionAttributesIfNeeded(cached)
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
