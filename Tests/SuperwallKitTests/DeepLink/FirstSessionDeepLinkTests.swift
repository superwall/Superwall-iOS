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

    let didRecord = storage.recordFirstSessionDeepLink(original: url, resolved: url)

    #expect(didRecord == true)
    #expect(storage.get(FirstSessionDeepLinkURL.self) == url.absoluteString)
  }

  @Test("Keeps the first recorded deep link when a second one arrives")
  func record_secondLink_keepsFirst() throws {
    let storage = makeStorage()
    let firstUrl = try #require(URL(string: "myapp://home?promo=first"))
    let secondUrl = try #require(URL(string: "myapp://home?promo=second"))

    #expect(storage.recordFirstSessionDeepLink(original: firstUrl, resolved: firstUrl) == true)
    #expect(storage.recordFirstSessionDeepLink(original: secondUrl, resolved: secondUrl) == false)

    #expect(storage.get(FirstSessionDeepLinkURL.self) == firstUrl.absoluteString)
  }

  @Test("Doesn't record when the first app session ended on a previous launch")
  func record_notFirstSession_returnsFalse() throws {
    let cache = CacheMock()
    cache.write(true, forType: DidTrackFirstSession.self)
    let storage = makeStorage(cache: cache)
    let url = try #require(URL(string: "myapp://home?promo=summer"))

    let didRecord = storage.recordFirstSessionDeepLink(original: url, resolved: url)

    #expect(didRecord == false)
    #expect(storage.get(FirstSessionDeepLinkURL.self) == nil)
  }

  @Test("Doesn't record after the first session has been tracked")
  func record_afterFirstSessionTracked_returnsFalse() throws {
    let storage = makeStorage()
    storage.recordFirstSessionTracked()
    let url = try #require(URL(string: "myapp://home?promo=summer"))

    let didRecord = storage.recordFirstSessionDeepLink(original: url, resolved: url)

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
  let enrichmentFetches = FetchCounter()

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

    let enrichmentFetches = enrichmentFetches
    router.fetchEnrichment = {
      enrichmentFetches.increment()
    }

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

  @Test("The first deep link is kept for enrichment as received and as routed")
  func route_firstSession_keepsLookupForEnrichment() async throws {
    let promo = UUID().uuidString
    let url = try #require(
      URL(string: "https://myapp.superwall.app/app-link/home?promo=\(promo)")
    )

    router.route(url: url)

    #expect(
      storage.get(FirstSessionDeepLinkLookup.self) == EnrichmentDeepLink(
        originalUrl: url.absoluteString,
        resolvedUrl: "myapp://home?promo=\(promo)"
      )
    )
    await enrichmentFetches.waitForCount(1)
    #expect(enrichmentFetches.count == 1)
  }

  @Test("Only the first deep link fetches enrichment")
  func route_secondLink_doesNotFetchEnrichmentAgain() async throws {
    let firstUrl = try #require(URL(string: "myapp://home?promo=\(UUID().uuidString)"))
    let secondUrl = try #require(URL(string: "myapp://home?promo=\(UUID().uuidString)"))

    router.route(url: firstUrl)
    await enrichmentFetches.waitForCount(1)
    router.route(url: secondUrl)
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(enrichmentFetches.count == 1)
    #expect(storage.get(FirstSessionDeepLinkLookup.self)?.originalUrl == firstUrl.absoluteString)
  }

  @Test("A deep link that arrives before config is captured straight away")
  func captureBeforeRouting_capturesAndFetchesEnrichment() async throws {
    let url = try #require(URL(string: "myapp://home?promo=\(UUID().uuidString)"))

    router.captureFirstSessionDeepLink(beforeRouting: url)

    #expect(storage.get(FirstSessionDeepLinkURL.self) == url.absoluteString)
    #expect(storedAttribute == url.absoluteString)
    await enrichmentFetches.waitForCount(1)

    // Routing it once config arrives doesn't capture it a second time.
    router.route(url: url)
    try await Task.sleep(nanoseconds: 100_000_000)
    #expect(enrichmentFetches.count == 1)
  }

  @Test(
    "Return and redemption links that arrive before config aren't captured",
    arguments: ["myapp://superwall/return", "myapp://superwall/redeem?code=TESTCODE"]
  )
  func captureBeforeRouting_superwallLink_doesNotCapture(urlString: String) throws {
    let url = try #require(URL(string: urlString))

    router.captureFirstSessionDeepLink(beforeRouting: url)

    #expect(storage.get(FirstSessionDeepLinkURL.self) == nil)
    #expect(storage.get(FirstSessionDeepLinkLookup.self) == nil)
    #expect(enrichmentFetches.count == 0)
  }

  @Test("A new user keeps the first deep link and its custom product page")
  func keptAcrossReset_includesUrlAndPage() {
    let urlString = "myapp://home?promo=\(UUID().uuidString)"
    storage.save(urlString, forType: FirstSessionDeepLinkURL.self)
    storage.save(
      CustomProductPage(id: "ppid-1", name: "Fitness"),
      forType: FirstSessionCustomProductPage.self
    )

    let kept = router.firstDeepLinkAttributesKeptAcrossReset()

    #expect(kept[DeepLinkRouter.firstDeepLinkUrlAttributeKey] as? String == urlString)
    #expect(kept[DeepLinkRouter.customProductPageIdAttributeKey] as? String == "ppid-1")
    #expect(kept[DeepLinkRouter.customProductPageNameAttributeKey] as? String == "Fitness")
  }

  @Test("A new user keeps only the deep link when it has no custom product page")
  func keptAcrossReset_noPage_includesOnlyUrl() {
    let urlString = "myapp://home?promo=\(UUID().uuidString)"
    storage.save(urlString, forType: FirstSessionDeepLinkURL.self)

    let kept = router.firstDeepLinkAttributesKeptAcrossReset()

    #expect(kept.count == 1)
    #expect(kept[DeepLinkRouter.firstDeepLinkUrlAttributeKey] as? String == urlString)
  }

  @Test("A new user keeps nothing when no deep link was stored")
  func keptAcrossReset_noStoredLink_isEmpty() {
    #expect(router.firstDeepLinkAttributesKeptAcrossReset().isEmpty)
  }
}

/// Counts calls made from the router's unstructured tasks.
final class FetchCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0

  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return value
  }

  func increment() {
    lock.lock()
    value += 1
    lock.unlock()
  }

  func waitForCount(_ expected: Int) async {
    for _ in 0..<200 {
      if count >= expected {
        return
      }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
  }
}

// MARK: - Enrichment lookup

@Suite
struct FirstDeepLinkEnrichmentTests {
  private let lookup = EnrichmentDeepLink(
    originalUrl: "https://myapp.superwall.app/app-link/fitness",
    resolvedUrl: "myapp://fitness"
  )

  private func makeDeviceHelper() -> (DeviceHelper, NetworkMock, Storage, DependencyContainer) {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.configManager.options.eventTrackingBehavior = .all
    let network = NetworkMock(
      options: dependencyContainer.makeSuperwallOptions(),
      factory: dependencyContainer
    )
    let storage = Storage(
      factory: StorageMock.DeviceInfoFactoryMock(),
      cache: CacheMock()
    )
    let deviceHelper = DeviceHelper(
      api: dependencyContainer.api,
      storage: storage,
      network: network,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer
    )
    return (deviceHelper, network, storage, dependencyContainer)
  }

  @Test("The first deep link goes out with the enrichment request")
  func getEnrichment_pendingLookup_sendsDeepLink() async throws {
    let (deviceHelper, network, storage, dependencyContainer) = makeDeviceHelper()
    storage.save(lookup, forType: FirstSessionDeepLinkLookup.self)

    try await deviceHelper.getEnrichment()

    #expect(network.enrichmentRequests.last?.deepLink == lookup)
    withExtendedLifetime(storage) {}
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test("An enrichment request has no deep link when none is waiting")
  func getEnrichment_noLookup_sendsNoDeepLink() async throws {
    let (deviceHelper, network, storage, dependencyContainer) = makeDeviceHelper()

    try await deviceHelper.getEnrichment()

    #expect(network.enrichmentRequests.count == 1)
    #expect(network.enrichmentRequests.last?.deepLink == nil)
    // The device helper doesn't keep its storage alive.
    withExtendedLifetime(storage) {}
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test("Saves the custom product page the server answers with")
  func getEnrichment_matched_savesPage() async throws {
    let (deviceHelper, network, storage, dependencyContainer) = makeDeviceHelper()
    storage.save(lookup, forType: FirstSessionDeepLinkLookup.self)
    network.enrichmentResponse = Enrichment(
      user: JSON([
        DeepLinkRouter.customProductPageIdAttributeKey: "ppid-1",
        DeepLinkRouter.customProductPageNameAttributeKey: "Fitness"
      ]),
      device: JSON([:]),
      deepLink: EnrichmentDeepLinkAnswer(matched: true)
    )

    try await deviceHelper.getEnrichment()

    #expect(
      storage.get(FirstSessionCustomProductPage.self) == CustomProductPage(id: "ppid-1", name: "Fitness")
    )
    #expect(storage.get(FirstSessionDeepLinkLookup.self) == nil)
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test("Stops sending the deep link once the server answers that no page has it")
  func getEnrichment_notMatched_stopsSending() async throws {
    let (deviceHelper, network, storage, dependencyContainer) = makeDeviceHelper()
    storage.save(lookup, forType: FirstSessionDeepLinkLookup.self)
    network.enrichmentResponse = Enrichment(
      user: JSON([:]),
      device: JSON([:]),
      deepLink: EnrichmentDeepLinkAnswer(matched: false)
    )

    try await deviceHelper.getEnrichment()
    try await deviceHelper.getEnrichment()

    #expect(storage.get(FirstSessionCustomProductPage.self) == nil)
    #expect(storage.get(FirstSessionDeepLinkLookup.self) == nil)
    #expect(network.enrichmentRequests.map(\.deepLink) == [lookup, nil])
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test("Keeps sending the deep link while the server hasn't answered it")
  func getEnrichment_unanswered_sendsAgain() async throws {
    let (deviceHelper, network, storage, dependencyContainer) = makeDeviceHelper()
    storage.save(lookup, forType: FirstSessionDeepLinkLookup.self)

    try await deviceHelper.getEnrichment()
    try await deviceHelper.getEnrichment()

    #expect(storage.get(FirstSessionDeepLinkLookup.self) == lookup)
    #expect(network.enrichmentRequests.map(\.deepLink) == [lookup, lookup])
    withExtendedLifetime(dependencyContainer) {}
  }

  @Test("Keeps the deep link for the next request when enrichment fails")
  func getEnrichment_failure_keepsLookup() async throws {
    let (deviceHelper, network, storage, dependencyContainer) = makeDeviceHelper()
    storage.save(lookup, forType: FirstSessionDeepLinkLookup.self)
    network.enrichmentError = NetworkError.unknown

    try? await deviceHelper.getEnrichment()

    #expect(storage.get(FirstSessionDeepLinkLookup.self) == lookup)
    withExtendedLifetime(dependencyContainer) {}
  }
}

// MARK: - Wire format

@Suite
struct FirstDeepLinkEnrichmentCodingTests {
  @Test("The request names the deep link's URLs in snake case")
  func request_withDeepLink_encodesBothUrls() throws {
    let request = EnrichmentRequest(
      user: JSON(["plan": "pro"]),
      device: JSON(["deviceModel": "iPhone17,1"]),
      deepLink: EnrichmentDeepLink(
        originalUrl: "https://myapp.superwall.app/app-link/fitness",
        resolvedUrl: "myapp://fitness"
      )
    )

    let data = try JSONEncoder.toSnakeCase.encode(request)
    let json = try JSON(data: data)

    #expect(json["deep_link"]["original_url"].string == "https://myapp.superwall.app/app-link/fitness")
    #expect(json["deep_link"]["resolved_url"].string == "myapp://fitness")
    #expect(json["device"]["deviceModel"].string == "iPhone17,1")
    #expect(json["user"]["plan"].string == "pro")
  }

  @Test("The request leaves the deep link out when there is none")
  func request_withoutDeepLink_omitsIt() throws {
    let request = EnrichmentRequest(user: JSON([:]), device: JSON([:]))

    let data = try JSONEncoder.toSnakeCase.encode(request)
    let json = try JSON(data: data)

    #expect(json["deep_link"].exists() == false)
  }

  @Test("The response's deep link answer is read when the server sends one")
  func response_decodesDeepLinkAnswer() throws {
    let answered = Data(
      #"{"user":{"customProductPageId":"ppid-1"},"device":{},"deep_link":{"matched":true}}"#.utf8
    )
    let unanswered = Data(#"{"user":{},"device":{}}"#.utf8)

    let enrichment = try JSONDecoder.fromSnakeCase.decode(Enrichment.self, from: answered)

    #expect(enrichment.deepLink == EnrichmentDeepLinkAnswer(matched: true))
    #expect(enrichment.user["customProductPageId"].string == "ppid-1")
    #expect(try JSONDecoder.fromSnakeCase.decode(Enrichment.self, from: unanswered).deepLink == nil)
  }

  @Test("A custom product page is read from the response's user attributes")
  func page_fromUserAttributes() {
    let named = CustomProductPage(
      userAttributes: JSON(["customProductPageId": "ppid-1", "customProductPageName": "Fitness"])
    )
    let unnamed = CustomProductPage(userAttributes: JSON(["customProductPageId": "ppid-2"]))

    #expect(named == CustomProductPage(id: "ppid-1", name: "Fitness"))
    #expect(unnamed == CustomProductPage(id: "ppid-2", name: nil))
    #expect(CustomProductPage(userAttributes: JSON([:])) == nil)
    #expect(CustomProductPage(userAttributes: JSON(["customProductPageId": ""])) == nil)
  }
}
