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

  /// Reads the attribute through the identity manager's serial queue, so it
  /// waits for any merge the router queued before it.
  private var storedAttribute: String? {
    dependencyContainer.identityManager
      .userAttributes[DeepLinkRouter.firstDeepLinkUrlAttributeKey] as? String
  }

  @Test("Routing a deep link during the first session sets the firstDeepLinkUrl user attribute")
  func route_firstSession_setsUserAttribute() throws {
    let url = try #require(URL(string: "myapp://home?promo=\(UUID().uuidString)"))

    router.route(url: url)

    #expect(storage.get(FirstSessionDeepLinkURL.self) == url.absoluteString)
    #expect(storedAttribute == url.absoluteString)
  }

  @Test("Only the first deep link of the first session is captured")
  func route_secondLink_keepsFirstAttribute() throws {
    let firstUrl = try #require(URL(string: "myapp://home?promo=\(UUID().uuidString)"))
    let secondUrl = try #require(URL(string: "myapp://home?promo=\(UUID().uuidString)"))

    router.route(url: firstUrl)
    router.route(url: secondUrl)

    #expect(storage.get(FirstSessionDeepLinkURL.self) == firstUrl.absoluteString)
    #expect(storedAttribute == firstUrl.absoluteString)
  }

  @Test("Superwall app-link deep links are captured in their mapped form")
  func route_superwallAppLink_capturesMappedUrl() throws {
    let promo = UUID().uuidString
    let url = try #require(
      URL(string: "https://myapp.superwall.app/app-link/home?promo=\(promo)")
    )

    router.route(url: url)

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

  private func storedAttribute(_ key: String) -> String? {
    dependencyContainer.identityManager.userAttributes[key] as? String
  }

  private func clearPageAttributes() {
    let removal: [String: Any?] = [
      DeepLinkRouter.customProductPageIdAttributeKey: nil,
      DeepLinkRouter.customProductPageNameAttributeKey: nil
    ]
    dependencyContainer.identityManager.mergeUserAttributes(removal)
  }

  @Test("Sets the custom product page whose deep link is the first deep link")
  func route_matchingPage_setsPageAttributes() throws {
    clearPageAttributes()
    let deepLink = "myapp://home?promo=\(UUID().uuidString)"
    let page = CustomProductPage(id: "ppid-1", name: "Fitness", deepLink: deepLink)
    var config = Config.stub()
    config.customProductPages = [page]
    dependencyContainer.configManager.store.update(ConfigUpdate.retrieved(config))

    router.route(url: try #require(URL(string: deepLink)))

    #expect(storage.get(FirstSessionCustomProductPage.self) == page)
    #expect(storedAttribute(DeepLinkRouter.customProductPageIdAttributeKey) == "ppid-1")
    #expect(storedAttribute(DeepLinkRouter.customProductPageNameAttributeKey) == "Fitness")
  }

  @Test("Matches a page whose deep link is a Superwall app-link before it's mapped")
  func route_appLinkPage_matchesOriginalUrl() throws {
    clearPageAttributes()
    let deepLink = "https://myapp.superwall.app/app-link/home?promo=\(UUID().uuidString)"
    let page = CustomProductPage(id: "ppid-2", name: nil, deepLink: deepLink)
    var config = Config.stub()
    config.customProductPages = [page]
    dependencyContainer.configManager.store.update(ConfigUpdate.retrieved(config))

    router.route(url: try #require(URL(string: deepLink)))

    #expect(storage.get(FirstSessionCustomProductPage.self) == page)
    #expect(storedAttribute(DeepLinkRouter.customProductPageIdAttributeKey) == "ppid-2")
  }

  @Test("Sets the custom product page when config arrives after the first deep link")
  func route_beforeConfig_matchesWhenConfigArrives() throws {
    clearPageAttributes()
    let deepLink = "myapp://home?promo=\(UUID().uuidString)"
    router.route(url: try #require(URL(string: deepLink)))
    #expect(storedAttribute(DeepLinkRouter.customProductPageIdAttributeKey) == nil)

    let page = CustomProductPage(id: "ppid-3", name: "Sleep", deepLink: deepLink)
    var config = Config.stub()
    config.customProductPages = [page]
    dependencyContainer.configManager.store.update(ConfigUpdate.retrieved(config))

    #expect(storage.get(FirstSessionCustomProductPage.self) == page)
    #expect(storedAttribute(DeepLinkRouter.customProductPageIdAttributeKey) == "ppid-3")
    #expect(storedAttribute(DeepLinkRouter.customProductPageNameAttributeKey) == "Sleep")
  }

  @Test("Sets only the deep link when no custom product page matches it")
  func route_noMatchingPage_setsOnlyUrl() throws {
    clearPageAttributes()
    var config = Config.stub()
    config.customProductPages = [
      CustomProductPage(id: "ppid-1", name: "Fitness", deepLink: "myapp://other")
    ]
    dependencyContainer.configManager.store.update(ConfigUpdate.retrieved(config))
    let url = try #require(URL(string: "myapp://home?promo=\(UUID().uuidString)"))

    router.route(url: url)

    #expect(storedAttribute == url.absoluteString)
    #expect(storage.get(FirstSessionCustomProductPage.self) == nil)
    #expect(storedAttribute(DeepLinkRouter.customProductPageIdAttributeKey) == nil)
  }

  @Test("A new user keeps the first deep link and its custom product page")
  func keptAcrossReset_includesUrlAndPage() {
    let urlString = "myapp://home?promo=\(UUID().uuidString)"
    storage.save(urlString, forType: FirstSessionDeepLinkURL.self)
    storage.save(
      CustomProductPage(id: "ppid-1", name: "Fitness", deepLink: urlString),
      forType: FirstSessionCustomProductPage.self
    )

    let kept = router.firstDeepLinkAttributesKeptAcrossReset()

    #expect(kept[DeepLinkRouter.firstDeepLinkUrlAttributeKey] as? String == urlString)
    #expect(kept[DeepLinkRouter.customProductPageIdAttributeKey] as? String == "ppid-1")
    #expect(kept[DeepLinkRouter.customProductPageNameAttributeKey] as? String == "Fitness")
  }

  @Test("A new user keeps nothing when no deep link was stored")
  func keptAcrossReset_noStoredLink_isEmpty() {
    #expect(router.firstDeepLinkAttributesKeptAcrossReset().isEmpty)
  }
}

// MARK: - Custom product page matching

@Suite
struct CustomProductPageMatchingTests {
  private let url = URL(string: "myapp://home")!

  @Test("Finds the page whose deep link is the URL")
  func matching_findsPage() {
    let page = CustomProductPage(id: "a", name: "A", deepLink: "myapp://home")
    let other = CustomProductPage(id: "b", name: "B", deepLink: "myapp://other")

    #expect(CustomProductPage.matching(url, in: [other, page]) == page)
  }

  @Test("Finds nothing when no page has the URL as its deep link")
  func matching_noMatch_isNil() {
    let page = CustomProductPage(id: "a", name: "A", deepLink: "myapp://other")

    #expect(CustomProductPage.matching(url, in: [page]) == nil)
    #expect(CustomProductPage.matching(url, in: []) == nil)
  }

  @Test("Finds nothing when different pages share the deep link")
  func matching_sharedDeepLink_isNil() {
    let first = CustomProductPage(id: "a", name: "A", deepLink: "myapp://home")
    let second = CustomProductPage(id: "b", name: "B", deepLink: "myapp://home")

    #expect(CustomProductPage.matching(url, in: [first, second]) == nil)
  }

  @Test("Finds the page when several of its versions have the deep link")
  func matching_samePageTwice_findsPage() {
    let page = CustomProductPage(id: "a", name: "A", deepLink: "myapp://home")

    #expect(CustomProductPage.matching(url, in: [page, page]) == page)
  }

  @Test("Matches a page whose deep link is a Superwall app-link against its mapped form")
  func matching_appLinkPage_matchesMappedUrl() {
    let page = CustomProductPage(
      id: "a",
      name: "A",
      deepLink: "https://myapp.superwall.app/app-link/home?promo=1"
    )
    let mapped = URL(string: "myapp://home?promo=1")!

    #expect(CustomProductPage.matching(mapped, in: [page]) == page)
  }
}

// MARK: - Config decoding

@Suite
struct CustomProductPagesConfigTests {
  private func configJson(_ extra: String) -> Data {
    """
    {
      "buildId": "abc",
      "triggerOptions": [],
      "paywallResponses": [],
      "logLevel": 0,
      "localization": { "locales": [] },
      "appSessionTimeoutMs": 3600000,
      "toggles": [{ "key": "enable_expression_params", "enabled": true }],
      "disablePreload": { "all": false, "triggers": [] }\(extra)
    }
    """.data(using: .utf8)!
  }

  @Test("Decodes the custom product pages, skipping any that are malformed")
  func decodes_skipsMalformed() throws {
    let json = configJson("""
    ,
      "custom_product_pages": [
        { "id": "a", "name": "Fitness", "deep_link": "myapp://fitness" },
        { "id": "b", "deep_link": "myapp://sleep" },
        { "name": "No ID", "deep_link": "myapp://broken" }
      ]
    """)

    let config = try JSONDecoder.fromSnakeCase.decode(Config.self, from: json)

    #expect(config.customProductPages == [
      CustomProductPage(id: "a", name: "Fitness", deepLink: "myapp://fitness"),
      CustomProductPage(id: "b", name: nil, deepLink: "myapp://sleep")
    ])
  }

  @Test("Leaves the custom product pages empty when the config has none")
  func decodes_missing_isNil() throws {
    let config = try JSONDecoder.fromSnakeCase.decode(Config.self, from: configJson(""))

    #expect(config.customProductPages == nil)
  }

  @Test("Keeps the custom product pages when the config is cached")
  func encodes_roundTrips() throws {
    var config = Config.stub()
    config.customProductPages = [
      CustomProductPage(id: "a", name: "Fitness", deepLink: "myapp://fitness")
    ]

    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(Config.self, from: data)

    #expect(decoded.customProductPages == config.customProductPages)
  }
}
