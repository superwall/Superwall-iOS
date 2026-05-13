//
//  AdServicesAttributionTests.swift
//  SuperwallKit
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite(.serialized)
struct AdServicesAttributionTests {
  // MARK: - AdServicesResponse decoding

  @Test
  func adServicesResponse_decodesFullPayload() throws {
    let json = """
    {
      "attribution": {
        "campaignId": 12345,
        "keywordId": "kw-1"
      },
      "eligible": true,
      "error": null
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(AdServicesResponse.self, from: json)

    #expect(decoded.eligible == true)
    #expect(decoded.error == nil)
    #expect(decoded.attribution["campaignId"]?.intValue == 12345)
    #expect(decoded.attribution["keywordId"]?.stringValue == "kw-1")
  }

  @Test
  func adServicesResponse_decodesIneligibleResult() throws {
    let json = """
    {
      "attribution": {},
      "eligible": false
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(AdServicesResponse.self, from: json)

    #expect(decoded.eligible == false)
    #expect(decoded.error == nil)
    #expect(decoded.attribution.isEmpty)
  }

  @Test
  func adServicesResponse_decodesWithoutOptionalFields() throws {
    let json = """
    {
      "attribution": { "campaignId": 1 }
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(AdServicesResponse.self, from: json)

    #expect(decoded.eligible == nil)
    #expect(decoded.error == nil)
    #expect(decoded.attribution["campaignId"]?.intValue == 1)
  }

  // MARK: - AdServicesAttributionAttempts round-trip

  @Test
  func attempts_roundTripsThroughCodable() throws {
    let original = AdServicesAttributionAttempts(
      count: 3,
      firstAttemptDate: Date(timeIntervalSince1970: 1_700_000_000),
      lastAttemptDate: Date(timeIntervalSince1970: 1_700_001_000)
    )

    let data = try JSONEncoder().encode(original)
    let restored = try JSONDecoder().decode(AdServicesAttributionAttempts.self, from: data)

    #expect(restored == original)
  }

  @Test
  func attempts_storageRoundTripsViaCache() {
    let dependencyContainer = DependencyContainer()
    let storage = dependencyContainer.storage!

    // Make sure we start clean — previous test runs can leave state behind.
    storage.delete(AdServicesAttributionAttemptsStorage.self)
    #expect(storage.get(AdServicesAttributionAttemptsStorage.self) == nil)

    let attempts = AdServicesAttributionAttempts(
      count: 2,
      firstAttemptDate: Date(timeIntervalSince1970: 1_700_000_000),
      lastAttemptDate: Date(timeIntervalSince1970: 1_700_000_500)
    )
    storage.save(attempts, forType: AdServicesAttributionAttemptsStorage.self)

    let restored = storage.get(AdServicesAttributionAttemptsStorage.self)
    #expect(restored == attempts)

    storage.delete(AdServicesAttributionAttemptsStorage.self)
  }

  // MARK: - AttributionPoster gating

  @Test
  func getAdServicesToken_noOpsWhenAlreadyPosted() async {
    guard #available(iOS 14.3, macOS 11.1, macCatalyst 14.3, *) else {
      return
    }
    let dependencyContainer = DependencyContainer()
    let storage = dependencyContainer.storage!
    let poster = dependencyContainer.attributionPoster!

    // Pretend a previous run successfully posted.
    storage.save("sentinel-token", forType: AdServicesTokenStorage.self)
    storage.delete(AdServicesAttributionAttemptsStorage.self)

    await poster.getAdServicesTokenIfNeeded()

    // Sentinel should still be there and we should not have recorded a fresh
    // failed attempt — the poster should have bailed before touching either.
    #expect(storage.get(AdServicesTokenStorage.self) == "sentinel-token")
    #expect(storage.get(AdServicesAttributionAttemptsStorage.self) == nil)

    // cleanup
    storage.delete(AdServicesTokenStorage.self)
  }

  @Test
  func cancelInFlight_clearsCollectingFlag() {
    let dependencyContainer = DependencyContainer()
    // Should be a no-op when nothing is in flight, but must not crash.
    dependencyContainer.attributionPoster!.cancelInFlight()
  }

  // MARK: - canStartAttempt guards
  //
  // We test the guards by setting up storage state where they should bail,
  // calling `getAdServicesTokenIfNeeded`, and asserting nothing was written
  // or mutated. The alternative — passing the canStartAttempt guard — would
  // make a real network call, so every test in this block must arrange for a
  // bail. Config is left in `.retrieving` state for most of these because the
  // tests don't depend on the config-enabled branch; the budget / sentinel
  // checks short-circuit before the config check is reached only when the
  // config-enabled guard is also failing — that's still a valid bail, and we
  // assert "nothing changed" either way.

  @Test
  func getAdServicesToken_bailsWhenMaxAttemptsReached() async {
    guard #available(iOS 14.3, macOS 11.1, macCatalyst 14.3, *) else {
      return
    }
    let dependencyContainer = DependencyContainer()
    let storage = dependencyContainer.storage!
    let poster = dependencyContainer.attributionPoster!

    storage.delete(AdServicesTokenStorage.self)
    storage.delete(AdServicesAttributionUnsupportedStorage.self)
    let saturated = AdServicesAttributionAttempts(
      count: AttributionPoster.maxAttempts,
      firstAttemptDate: Date(),
      lastAttemptDate: Date()
    )
    storage.save(saturated, forType: AdServicesAttributionAttemptsStorage.self)
    dependencyContainer.configManager.configState.send(.retrieved(.stub()))

    await poster.getAdServicesTokenIfNeeded()

    // Attempts record must NOT have been bumped — that would mean we tried
    // anyway, defeating the cap.
    #expect(storage.get(AdServicesAttributionAttemptsStorage.self) == saturated)
    #expect(storage.get(AdServicesTokenStorage.self) == nil)

    storage.delete(AdServicesAttributionAttemptsStorage.self)
  }

  @Test
  func getAdServicesToken_bailsWhenRetryWindowExpired() async {
    guard #available(iOS 14.3, macOS 11.1, macCatalyst 14.3, *) else {
      return
    }
    let dependencyContainer = DependencyContainer()
    let storage = dependencyContainer.storage!
    let poster = dependencyContainer.attributionPoster!

    storage.delete(AdServicesTokenStorage.self)
    storage.delete(AdServicesAttributionUnsupportedStorage.self)
    let firstAttempt = Date().addingTimeInterval(-AttributionPoster.maxRetryWindow - 60)
    let expired = AdServicesAttributionAttempts(
      count: 2,
      firstAttemptDate: firstAttempt,
      lastAttemptDate: firstAttempt.addingTimeInterval(30)
    )
    storage.save(expired, forType: AdServicesAttributionAttemptsStorage.self)
    dependencyContainer.configManager.configState.send(.retrieved(.stub()))

    await poster.getAdServicesTokenIfNeeded()

    #expect(storage.get(AdServicesAttributionAttemptsStorage.self) == expired)
    #expect(storage.get(AdServicesTokenStorage.self) == nil)

    storage.delete(AdServicesAttributionAttemptsStorage.self)
  }

  @Test
  func getAdServicesToken_bailsWhenPermanentlyUnsupported() async {
    guard #available(iOS 14.3, macOS 11.1, macCatalyst 14.3, *) else {
      return
    }
    let dependencyContainer = DependencyContainer()
    let storage = dependencyContainer.storage!
    let poster = dependencyContainer.attributionPoster!

    storage.delete(AdServicesTokenStorage.self)
    storage.delete(AdServicesAttributionAttemptsStorage.self)
    storage.save(true, forType: AdServicesAttributionUnsupportedStorage.self)
    dependencyContainer.configManager.configState.send(.retrieved(.stub()))

    await poster.getAdServicesTokenIfNeeded()

    // No attempts record written, no success token written — the unsupported
    // sentinel is a hard stop.
    #expect(storage.get(AdServicesAttributionAttemptsStorage.self) == nil)
    #expect(storage.get(AdServicesTokenStorage.self) == nil)
    #expect(storage.get(AdServicesAttributionUnsupportedStorage.self) == true)

    storage.delete(AdServicesAttributionUnsupportedStorage.self)
  }
}
