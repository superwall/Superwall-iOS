//
//  FirstSessionDeepLinkTests.swift
//  SuperwallKit
//
//  Tests for capturing the first deep link of the first app session
//  as a user attribute for product page attribution.
//
// swiftlint:disable all

import Testing
import Foundation
@testable import SuperwallKit

// MARK: - Storage gating

@Suite
struct FirstSessionDeepLinkStorageTests {
  private func makeStorage(cache: Cache = CacheMock()) -> Storage {
    Storage(
      factory: StorageMock.DeviceInfoFactoryMock(),
      cache: cache
    )
  }

  @Test("Records the deep link during the first app session")
  func record_firstSession_recordsAndReturnsTrue() throws {
    let storage = makeStorage()
    let url = try #require(URL(string: "myapp://home?promo=summer"))

    let didRecord = storage.recordFirstSessionDeepLink(url)

    #expect(didRecord == true)
    #expect(storage.get(FirstSessionDeepLinkURL.self) == url.absoluteString)
  }

  @Test("Keeps the first recorded deep link when a second one arrives")
  func record_secondLink_keepsFirst() throws {
    let storage = makeStorage()
    let firstUrl = try #require(URL(string: "myapp://home?promo=first"))
    let secondUrl = try #require(URL(string: "myapp://home?promo=second"))

    #expect(storage.recordFirstSessionDeepLink(firstUrl) == true)
    #expect(storage.recordFirstSessionDeepLink(secondUrl) == false)

    #expect(storage.get(FirstSessionDeepLinkURL.self) == firstUrl.absoluteString)
  }

  @Test("Doesn't record when the first app session ended on a previous launch")
  func record_notFirstSession_returnsFalse() throws {
    let cache = CacheMock()
    cache.write(true, forType: DidTrackFirstSession.self)
    let storage = makeStorage(cache: cache)
    let url = try #require(URL(string: "myapp://home?promo=summer"))

    let didRecord = storage.recordFirstSessionDeepLink(url)

    #expect(didRecord == false)
    #expect(storage.get(FirstSessionDeepLinkURL.self) == nil)
  }

  @Test("Doesn't record after the first session has been tracked")
  func record_afterFirstSessionTracked_returnsFalse() throws {
    let storage = makeStorage()
    storage.recordFirstSessionTracked()
    let url = try #require(URL(string: "myapp://home?promo=summer"))

    let didRecord = storage.recordFirstSessionDeepLink(url)

    #expect(didRecord == false)
    #expect(storage.get(FirstSessionDeepLinkURL.self) == nil)
  }
}

// MARK: - Router capture

@Suite(.serialized)
struct FirstSessionDeepLinkRouterTests {
  let dependencyContainer: DependencyContainer
  let storage: Storage
  let router: DeepLinkRouter

  init() {
    dependencyContainer = DependencyContainer()
    storage = Storage(
      factory: StorageMock.DeviceInfoFactoryMock(),
      cache: CacheMock()
    )
    router = DeepLinkRouter(
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      debugManager: dependencyContainer.debugManager,
      configManager: dependencyContainer.configManager,
      storage: storage,
      identityManager: dependencyContainer.identityManager
    )

    // Remove any attribute persisted to disk by previous test runs.
    let removal: [String: Any?] = [DeepLinkRouter.firstDeepLinkUrlAttributeKey: nil]
    dependencyContainer.identityManager.mergeUserAttributes(removal)
  }

  private var storedAttribute: String? {
    dependencyContainer.identityManager
      .userAttributes[DeepLinkRouter.firstDeepLinkUrlAttributeKey] as? String
  }

  @Test("Routing a deep link during the first session sets the firstDeepLinkUrl user attribute")
  func route_firstSession_setsUserAttribute() async throws {
    let url = try #require(URL(string: "myapp://home?promo=\(UUID().uuidString)"))

    router.route(url: url)
    try await Task.sleep(nanoseconds: 500_000_000)

    #expect(storage.get(FirstSessionDeepLinkURL.self) == url.absoluteString)
    #expect(storedAttribute == url.absoluteString)
  }

  @Test("Only the first deep link of the first session is captured")
  func route_secondLink_keepsFirstAttribute() async throws {
    let firstUrl = try #require(URL(string: "myapp://home?promo=\(UUID().uuidString)"))
    let secondUrl = try #require(URL(string: "myapp://home?promo=\(UUID().uuidString)"))

    router.route(url: firstUrl)
    router.route(url: secondUrl)
    try await Task.sleep(nanoseconds: 500_000_000)

    #expect(storage.get(FirstSessionDeepLinkURL.self) == firstUrl.absoluteString)
    #expect(storedAttribute == firstUrl.absoluteString)
  }

  @Test("Superwall app-link deep links are captured in their mapped form")
  func route_superwallAppLink_capturesMappedUrl() async throws {
    let promo = UUID().uuidString
    let url = try #require(
      URL(string: "https://myapp.superwall.app/app-link/home?promo=\(promo)")
    )

    router.route(url: url)
    try await Task.sleep(nanoseconds: 500_000_000)

    // The mapped form is captured, consistent with the deepLink_open event.
    #expect(storage.get(FirstSessionDeepLinkURL.self) == "myapp://home?promo=\(promo)")
    #expect(storedAttribute == "myapp://home?promo=\(promo)")
  }

  @Test("Redemption code deep links aren't captured for attribution")
  func route_redemptionLink_doesNotCapture() async throws {
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false
    let mockNetwork = NetworkMock(
      options: options,
      factory: dependencyContainer
    )
    let redeemer = WebEntitlementRedeemer(
      network: mockNetwork,
      storage: storage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      superwall: superwall
    )
    let router = DeepLinkRouter(
      webEntitlementRedeemer: redeemer,
      debugManager: dependencyContainer.debugManager,
      configManager: dependencyContainer.configManager,
      storage: storage,
      identityManager: dependencyContainer.identityManager
    )
    let url = try #require(URL(string: "myapp://superwall/redeem?code=TESTCODE"))

    router.route(url: url)

    #expect(storage.get(FirstSessionDeepLinkURL.self) == nil)

    // Let the fire-and-forget redemption task finish against the mock network
    // before the redeemer deallocates.
    try await Task.sleep(nanoseconds: 500_000_000)
  }

  @Test("Re-applies the stored deep link to user attributes after a reset")
  func reapply_appliesStoredLink() async throws {
    let urlString = "myapp://home?promo=\(UUID().uuidString)"
    storage.save(urlString, forType: FirstSessionDeepLinkURL.self)

    router.reapplyFirstSessionDeepLinkAttribute()
    try await Task.sleep(nanoseconds: 500_000_000)

    #expect(storedAttribute == urlString)
  }

  @Test("Reapply is a no-op when no deep link was stored")
  func reapply_noStoredLink_doesNotSetAttribute() async throws {
    router.reapplyFirstSessionDeepLinkAttribute()
    try await Task.sleep(nanoseconds: 300_000_000)

    #expect(storedAttribute == nil)
  }
}
