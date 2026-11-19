//
//  TeleportColdStartTests.swift
//  SuperwallKit
//
//  Created by Christo Todorov on 19/11/2026.
//
// swiftlint:disable all

import Testing
@testable import SuperwallKit
import Foundation

/// A teleport purchase finishes after iOS ends the app while the checkout is open in Safari:
/// the return link that relaunches it carries the checkout, and the SDK redeems it.
@Suite(.serialized)
struct TeleportColdStartTests {
  let dependencyContainer = DependencyContainer()

  init() {
    dependencyContainer.storage.delete(PendingStripeCheckoutPollStorage.self)
    dependencyContainer.storage.delete(PendingTeleportStorage.self)
  }

  // MARK: - Helpers

  private func makeRedeemer(
    storage: StorageMock,
    network: NetworkMock,
    superwall: Superwall
  ) -> WebEntitlementRedeemer {
    WebEntitlementRedeemer(
      network: network,
      storage: storage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      stripePendingPollIntervalNs: 1_000_000,
      stripePendingPollTimeoutNs: 5_000_000_000,
      claimedTeleportRecheckDelays: [0, 0],
      superwall: superwall
    )
  }

  private func makeNetwork() -> NetworkMock {
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false
    return NetworkMock(options: options, factory: dependencyContainer)
  }

  private func redeemedResponse(code: String = "redemption_123") -> Result<RedeemResponse, Error> {
    let entitlements: Set<Entitlement> = [.stub()]
    let result = RedemptionResult.success(
      code: code,
      redemptionInfo: .init(
        ownership: .appUser(appUserId: "appUserId"),
        purchaserInfo: .init(
          appUserId: "appUserId",
          email: nil,
          storeIdentifiers: .stripe(customerId: "cus_123", subscriptionIds: ["sub_123"])
        ),
        entitlements: entitlements
      )
    )
    return .success(
      RedeemResponse(
        results: [result],
        customerInfo: CustomerInfo(
          subscriptions: [],
          nonSubscriptions: [],
          entitlements: Array(entitlements)
        )
      )
    )
  }

  private func makeSuperwall() -> (Superwall, MockSuperwallDelegate) {
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let mockDelegate = MockSuperwallDelegate()
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = mockDelegate
    superwall.delegate = mockDelegate
    dependencyContainer.delegateAdapter = delegateAdapter
    return (superwall, mockDelegate)
  }

  private let purchase = PurchasedReturn(
    checkoutContextId: "ctx_1",
    productId: "prod_1",
    completion: .purchase(productId: "prod_1", shouldDismiss: true)
  )

  // MARK: - Reading the return link

  @Test("A purchased return link carries its checkout, product and dismissal")
  func purchasedReturnLink_parsesCheckout() {
    let url = URL(
      string: "https://myapp.superwall.link/app-link/superwall/return?reason=purchased&checkout_context_id=ctx_1&product_identifier=prod_1&should_dismiss=true"
    )!
    #expect(url.superwallPurchasedReturn == purchase)

    let scheme = URL(
      string: "myapp://superwall/return?reason=purchased&checkout_context_id=ctx_1&product_identifier=prod_1&should_dismiss=false"
    )!
    #expect(
      scheme.superwallPurchasedReturn?.completion
        == .purchase(productId: "prod_1", shouldDismiss: false)
    )
  }

  @Test("A purchased return link that doesn't say whether to dismiss finishes as a restore")
  func purchasedReturnLink_withoutDismissal_restores() {
    let url = URL(
      string: "myapp://superwall/return?reason=purchased&checkout_context_id=ctx_1"
    )!
    #expect(
      url.superwallPurchasedReturn
        == PurchasedReturn(checkoutContextId: "ctx_1", productId: "", completion: .restore)
    )
  }

  @Test(
    "Only a purchased return link with a checkout id counts as a purchase",
    arguments: [
      "myapp://superwall/return?reason=closed&checkout_context_id=ctx_1",
      "myapp://superwall/return?checkout_context_id=ctx_1",
      "myapp://superwall/return?reason=purchased",
      "myapp://superwall/return?reason=purchased&checkout_context_id=",
      "myapp://superwall/return",
      "myapp://home?reason=purchased&checkout_context_id=ctx_1",
      "https://example.com/app-link/superwall/return?reason=purchased&checkout_context_id=ctx_1"
    ]
  )
  func otherLinks_areNotPurchases(link: String) {
    #expect(URL(string: link)!.superwallPurchasedReturn == nil)
  }

  // MARK: - Routing

  private final class RecordedPurchases: @unchecked Sendable {
    private let lock = NSLock()
    private var purchases: [PurchasedReturn] = []

    func append(_ purchase: PurchasedReturn) {
      lock.lock()
      defer { lock.unlock() }
      purchases.append(purchase)
    }

    var all: [PurchasedReturn] {
      lock.lock()
      defer { lock.unlock() }
      return purchases
    }
  }

  private func route(_ link: String) -> (handled: Bool, purchases: [PurchasedReturn]) {
    let container = DependencyContainer()
    let router = container.deepLinkRouter!
    let recorded = RecordedPurchases()
    router.trackEvent = { _ in }
    router.presentedPaywallInfo = { nil }
    router.recordPurchasedReturn = { recorded.append($0) }
    let handled = router.route(url: URL(string: link)!)
    return (handled, recorded.all)
  }

  @Test("Routing a purchased return link hands its checkout to the redeemer")
  func route_purchasedReturnLink_recordsPurchase() {
    let result = route(
      "https://myapp.superwall.link/app-link/superwall/return?reason=purchased&checkout_context_id=ctx_1&product_identifier=prod_1&should_dismiss=true"
    )
    #expect(result.handled == true)
    #expect(result.purchases == [purchase])
  }

  @Test(
    "Routing a closed or bare return link records no purchase",
    arguments: [
      "myapp://superwall/return?reason=closed",
      "myapp://superwall/return",
      "myapp://superwall/return?reason=purchased"
    ]
  )
  func route_otherReturnLinks_recordNothing(link: String) {
    let result = route(link)
    #expect(result.handled == true)
    #expect(result.purchases.isEmpty)
  }

  // MARK: - Redeeming

  @Test("A purchased return link on a cold launch redeems the checkout")
  func coldLaunch_purchasedReturn_redeems() async {
    let (superwall, mockDelegate) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    network.pollRedemptionResultResponses = [redeemedResponse()]
    // A fresh redeemer: the paywall that teleported, and anything it knew, is gone.
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)

    await redeemer.handlePurchasedReturn(purchase)

    #expect(network.pollRedemptionResultCallCount == 1)
    #expect(network.pollRedemptionResultRequest?.checkoutContextId == "ctx_1")
    #expect(mockDelegate.receivedResult?.code == "redemption_123")
    #expect(storage.get(PendingStripeCheckoutPollStorage.self) == nil)
    #expect(await redeemer.shouldShowStripeRecoveryLoadingOnPaywallOpen() == false)
  }

  @Test("A paywall opened before the purchase is redeemed waits for it, then the redemption finishes it")
  func coldLaunch_paywallOpenedBeforeRedemption_isBlockedUntilRedeemed() async {
    let (superwall, mockDelegate) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    // The first poll fails, as it might before the network is up after launch.
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)

    await redeemer.handlePurchasedReturn(purchase)

    let pending = storage.get(PendingStripeCheckoutPollStorage.self)
    #expect(pending?.checkoutContextId == "ctx_1")
    #expect(pending?.completion == .purchase(productId: "prod_1", shouldDismiss: true))

    // The paywall that opens next is held behind the spinner, and its poll redeems the code.
    #expect(await redeemer.shouldShowStripeRecoveryLoadingOnPaywallOpen() == true)
    network.pollRedemptionResultResponses = [redeemedResponse()]
    #expect(await redeemer.pollOrWaitForActiveStripePoll() == true)
    #expect(mockDelegate.receivedResult?.code == "redemption_123")
    #expect(storage.get(PendingStripeCheckoutPollStorage.self) == nil)
  }

  @Test("A purchase stored by the return link survives the app being ended again")
  func purchasedReturn_survivesAnotherLaunch() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let first = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await first.handlePurchasedReturn(purchase)

    let second = makeRedeemer(storage: storage, network: network, superwall: superwall)
    network.pollRedemptionResultResponses = [redeemedResponse()]
    #expect(await second.shouldShowStripeRecoveryLoadingOnPaywallOpen() == true)
    await second.pollPendingStripeCheckoutOnForegroundIfNeeded()
    #expect(storage.get(PendingStripeCheckoutPollStorage.self) == nil)
  }

  @Test("Without a purchased return link a paywall is never held")
  func noPurchasedReturn_neverBlocks() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)

    #expect(await redeemer.shouldShowStripeRecoveryLoadingOnPaywallOpen() == false)
    #expect(await redeemer.pollOrWaitForActiveStripePoll() == false)
    #expect(network.pollRedemptionResultCallCount == 0)
  }

  @Test("A return link after the page already redeemed the purchase does nothing")
  func warmReturn_pageFirst_redeemsOnce() async {
    let (superwall, mockDelegate) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    network.pollRedemptionResultResponses = [redeemedResponse()]
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)

    await redeemer.handleStripeCheckoutComplete(
      contextId: "ctx_1",
      productId: "prod_1",
      completion: .purchase(productId: "prod_1", shouldDismiss: true)
    )
    await redeemer.handlePurchasedReturn(purchase)

    #expect(network.pollRedemptionResultCallCount == 1)
    #expect(mockDelegate.willRedeemCallCount == 1)
    #expect(storage.get(PendingStripeCheckoutPollStorage.self) == nil)
  }

  @Test("A return link while the page's poll is in flight waits for it and redeems once")
  func warmReturn_whilePagePolls_redeemsOnce() async {
    let (superwall, mockDelegate) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    network.pollRedemptionResultResponses = Array(
      repeating: .success(RedeemResponse(results: [], customerInfo: .blank(), status: .pending)),
      count: 20
    ) + [redeemedResponse()]
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)

    let page = Task {
      await redeemer.handleStripeCheckoutComplete(
        contextId: "ctx_1",
        productId: "prod_1",
        completion: .purchase(productId: "prod_1", shouldDismiss: true)
      )
    }
    while network.pollRedemptionResultCallCount == 0 {
      try? await Task.sleep(nanoseconds: 1_000_000)
    }
    await redeemer.handlePurchasedReturn(purchase)
    await page.value

    #expect(network.pollRedemptionResultCallCount == 21)
    #expect(mockDelegate.willRedeemCallCount == 1)
    #expect(storage.get(PendingStripeCheckoutPollStorage.self) == nil)
  }

  @Test("A return link for a newer checkout replaces an older pending one")
  func purchasedReturn_replacesOlderPendingCheckout() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_old", productId: "prod_old")

    await redeemer.handlePurchasedReturn(purchase)

    #expect(network.pollRedemptionResultRequest?.checkoutContextId == "ctx_1")
    #expect(storage.get(PendingStripeCheckoutPollStorage.self)?.checkoutContextId == "ctx_1")
  }

  // MARK: - Storing the teleport when Safari opens

  @MainActor
  private func makeMessageHandler() -> (PaywallMessageHandler, PaywallMessageHandlerDelegateMock) {
    let container = DependencyContainer()
    let messageHandler = PaywallMessageHandler(
      receiptManager: container.receiptManager,
      factory: container,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: container.customCallbackRegistry
    )
    let webView = FakeWebView(
      isiOSAppOnMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: container
    )
    let delegate = PaywallMessageHandlerDelegateMock(paywallInfo: .stub(), webView: webView)
    messageHandler.delegate = delegate
    messageHandler.trackEvent = { _ in }
    return (messageHandler, delegate)
  }

  private let checkoutUrl = URL(string: "https://example.com/sw-teleport/abc")!

  @Test("open_url_external reads the teleport id, product and dismissal a page sends")
  func decodeOpenUrlExternal_teleportDetails() throws {
    let json = """
    {
      "version": 1,
      "payload": {
        "events": [
          {
            "eventName": "open_url_external",
            "url": "https://example.com/sw-teleport/abc",
            "teleport": true,
            "teleport_id": "tp_1",
            "product_identifier": "prod_1",
            "should_dismiss": false
          }
        ]
      }
    }
    """
    let wrapped = try JSONDecoder.fromSnakeCase.decode(
      WrappedPaywallMessages.self,
      from: json.data(using: .utf8)!
    )
    #expect(wrapped.payload.messages.first == .openUrlInSafari(
      checkoutUrl,
      isTeleport: true,
      teleport: TeleportOpening(teleportId: "tp_1", productId: "prod_1", shouldDismiss: false)
    ))
  }

  @Test("A link that isn't a teleport carries no teleport details")
  func decodeOpenUrlExternal_notTeleport_ignoresDetails() throws {
    let json = """
    {"version": 1, "payload": {"events": [
      {"eventName": "open_url_external", "url": "https://example.com/sw-teleport/abc", "teleport_id": "tp_1"}
    ]}}
    """
    let wrapped = try JSONDecoder.fromSnakeCase.decode(
      WrappedPaywallMessages.self,
      from: json.data(using: .utf8)!
    )
    #expect(wrapped.payload.messages.first == .openUrlInSafari(checkoutUrl))
  }

  @Test("Today's page: the teleport is named by the checkout start sent just before Safari opens")
  @MainActor
  func teleportOpen_takesIdFromCheckoutStart() {
    let (handler, delegate) = makeMessageHandler()
    // What `teleport/flow.ts` `begin()` posts today.
    handler.handle(.stripeCheckoutStart(checkoutContextId: "tp_1", productId: "prod_1"))
    handler.handle(.openUrlInSafari(checkoutUrl, isTeleport: true))

    #expect(delegate.openedTeleports.map(\.teleportId) == ["tp_1"])
    #expect(delegate.openedTeleports.first?.productId == "prod_1")
    #expect(delegate.openedTeleports.first?.shouldDismiss == nil)
  }

  @Test("A page that names its teleport is taken at its word")
  @MainActor
  func teleportOpen_prefersIdFromMessage() {
    let (handler, delegate) = makeMessageHandler()
    handler.handle(.stripeCheckoutStart(checkoutContextId: "tp_old", productId: "prod_old"))
    handler.handle(.openUrlInSafari(
      checkoutUrl,
      isTeleport: true,
      teleport: TeleportOpening(teleportId: "tp_1", productId: "prod_1", shouldDismiss: true)
    ))

    #expect(delegate.openedTeleports == [
      PendingTeleportState(
        teleportId: "tp_1",
        productId: "prod_1",
        shouldDismiss: true,
        openedAt: delegate.openedTeleports.first?.openedAt ?? Date()
      )
    ])
  }

  @Test("Nothing is stored for a teleport that nothing names, or for a plain Safari link")
  @MainActor
  func teleportOpen_withoutId_recordsNothing() {
    let (handler, delegate) = makeMessageHandler()
    handler.handle(.openUrlInSafari(checkoutUrl, isTeleport: true))

    // A plain link uses up the checkout start, so a later teleport can't take its id.
    handler.handle(.stripeCheckoutStart(checkoutContextId: "tp_1", productId: "prod_1"))
    handler.handle(.openUrlInSafari(checkoutUrl))
    handler.handle(.openUrlInSafari(checkoutUrl, isTeleport: true))

    // So does a checkout the page settled.
    handler.handle(.stripeCheckoutStart(checkoutContextId: "tp_2", productId: "prod_1"))
    handler.handle(.stripeCheckoutAbandon(checkoutContextId: "tp_2", productId: "prod_1"))
    handler.handle(.openUrlInSafari(checkoutUrl, isTeleport: true))

    #expect(delegate.openedTeleports.isEmpty)
  }

  // MARK: - Recovering a stored teleport

  private let teleport = PendingTeleportState(
    teleportId: "tp_1",
    productId: "prod_offered",
    shouldDismiss: true
  )

  private func status(
    _ status: String,
    checkoutContextId: String? = "ctx_1",
    product: String? = "prod_1"
  ) -> Result<TeleportStatusResponse, Error> {
    .success(
      TeleportStatusResponse(
        status: status,
        checkoutContextId: checkoutContextId,
        checkoutProductIdentifier: product
      )
    )
  }

  @Test("A teleport the app was ended during, read completed on launch, is redeemed")
  func coldLaunch_completedTeleport_redeems() async {
    let (superwall, mockDelegate) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let before = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await before.registerTeleportOpen(teleport)
    #expect(storage.get(PendingTeleportStorage.self) == teleport)

    // Relaunched by hand: no return link, and the page that opened the teleport is gone.
    network.teleportStatusResponses = [status("completed")]
    network.pollRedemptionResultResponses = [redeemedResponse()]
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    // Only a teleport is known: nothing holds a paywall yet.
    #expect(await redeemer.shouldShowStripeRecoveryLoadingOnPaywallOpen() == false)

    #expect(await redeemer.recoverPendingTeleport() == true)

    #expect(network.teleportStatusRequests == ["tp_1"])
    #expect(network.pollRedemptionResultRequest?.checkoutContextId == "ctx_1")
    #expect(mockDelegate.receivedResult?.code == "redemption_123")
    #expect(storage.get(PendingTeleportStorage.self) == nil)
    #expect(storage.get(PendingStripeCheckoutPollStorage.self) == nil)
  }

  @Test("Once a teleport reads completed, a paywall waits behind the spinner until it's redeemed")
  func completedTeleport_notYetRedeemed_blocksPaywall() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    network.teleportStatusResponses = [status("completed")]
    // The redemption isn't there yet (the first poll fails).
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerTeleportOpen(teleport)

    #expect(await redeemer.recoverPendingTeleport() == true)

    let pending = storage.get(PendingStripeCheckoutPollStorage.self)
    #expect(pending?.checkoutContextId == "ctx_1")
    // The product the checkout sold, not the one the paywall offered, finishing as the page asked.
    #expect(pending?.productId == "prod_1")
    #expect(pending?.completion == .purchase(productId: "prod_1", shouldDismiss: true))
    #expect(await redeemer.shouldShowStripeRecoveryLoadingOnPaywallOpen() == true)
  }

  @Test(
    "A teleport that isn't paid is forgotten and never holds a paywall",
    arguments: ["expired", "something_new"]
  )
  func unpaidTeleport_isForgotten(teleportStatus: String) async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    network.teleportStatusResponses = [status(teleportStatus)]
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerTeleportOpen(teleport)
    let fresh = makeRedeemer(storage: storage, network: network, superwall: superwall)

    #expect(await fresh.recoverPendingTeleport() == false)

    #expect(storage.get(PendingTeleportStorage.self) == nil)
    #expect(network.pollRedemptionResultCallCount == 0)
    #expect(await fresh.shouldShowStripeRecoveryLoadingOnPaywallOpen() == false)
  }

  @Test("A claimed teleport whose checkout is paid is redeemed before the backend marks it")
  func claimedTeleport_paidCheckout_redeems() async {
    let (superwall, mockDelegate) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerTeleportOpen(teleport)
    network.teleportStatusResponses = [status("claimed")]
    network.checkoutStatusResponses = [.success(CheckoutStatusResponse(status: "completed"))]
    network.pollRedemptionResultResponses = [redeemedResponse()]
    let fresh = makeRedeemer(storage: storage, network: network, superwall: superwall)

    #expect(await fresh.recoverPendingTeleport() == true)

    #expect(network.checkoutStatusRequests == ["ctx_1"])
    #expect(network.pollRedemptionResultRequest?.checkoutContextId == "ctx_1")
    #expect(mockDelegate.receivedResult?.code == "redemption_123")
    #expect(storage.get(PendingTeleportStorage.self) == nil)
  }

  @Test("A claimed teleport paid a moment after launch is redeemed on a later look")
  func claimedTeleport_paidOnRecheck_redeems() async {
    let (superwall, mockDelegate) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerTeleportOpen(teleport)
    // The app is back before the payment lands: the first look reads it unpaid.
    network.teleportStatusResponses = [status("claimed"), status("completed")]
    network.checkoutStatusResponses = [.success(CheckoutStatusResponse(status: "pending"))]
    network.pollRedemptionResultResponses = [redeemedResponse()]
    let fresh = makeRedeemer(storage: storage, network: network, superwall: superwall)

    // The caller doesn't wait for the later look; it runs in the background.
    #expect(await fresh.recoverPendingTeleport() == false)
    #expect(await fresh.waitForClaimedTeleportRecheck() == true)

    #expect(network.teleportStatusRequests == ["tp_1", "tp_1"])
    #expect(mockDelegate.receivedResult?.code == "redemption_123")
    #expect(storage.get(PendingTeleportStorage.self) == nil)
  }

  @Test("A claimed teleport that stays unpaid is kept for later and never holds a paywall")
  func claimedTeleport_unpaid_isKept() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerTeleportOpen(teleport)
    network.teleportStatusResponses = [status("claimed"), status("claimed"), status("claimed")]
    network.checkoutStatusResponses = Array(
      repeating: .success(CheckoutStatusResponse(status: "pending")),
      count: 3
    )
    let fresh = makeRedeemer(storage: storage, network: network, superwall: superwall)

    #expect(await fresh.recoverPendingTeleport() == false)
    #expect(await fresh.waitForClaimedTeleportRecheck() == false)

    // The first look and one for each recheck delay, then it waits for the next foreground.
    #expect(network.teleportStatusRequests.count == 3)
    #expect(network.checkoutStatusRequests.count == 3)
    #expect(storage.get(PendingTeleportStorage.self) == teleport)
    #expect(network.pollRedemptionResultCallCount == 0)
    #expect(await fresh.shouldShowStripeRecoveryLoadingOnPaywallOpen() == false)
  }

  @Test("A later foreground looks at an unpaid claimed teleport once, without rechecks")
  func claimedTeleport_unpaid_laterForegroundReadsOnce() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerTeleportOpen(teleport)
    network.teleportStatusResponses = Array(repeating: status("claimed"), count: 4)
    network.checkoutStatusResponses = Array(
      repeating: .success(CheckoutStatusResponse(status: "pending")),
      count: 4
    )
    let fresh = makeRedeemer(storage: storage, network: network, superwall: superwall)
    #expect(await fresh.recoverPendingTeleport() == false)
    #expect(await fresh.waitForClaimedTeleportRecheck() == false)

    // The next foreground of the same launch.
    #expect(await fresh.recoverPendingTeleport() == false)

    #expect(network.teleportStatusRequests.count == 4)
    #expect(network.checkoutStatusRequests.count == 4)
    #expect(storage.get(PendingTeleportStorage.self) == teleport)
  }

  @Test("A second look while the rechecks run makes no request")
  func claimedTeleport_lookDuringRechecks_isSkipped() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerTeleportOpen(teleport)
    network.teleportStatusResponses = Array(repeating: status("claimed"), count: 3)
    network.checkoutStatusResponses = Array(
      repeating: .success(CheckoutStatusResponse(status: "pending")),
      count: 3
    )
    let fresh = WebEntitlementRedeemer(
      network: network,
      storage: storage,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      delegate: dependencyContainer.delegateAdapter,
      purchaseController: MockPurchaseController(),
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      stripePendingPollIntervalNs: 1_000_000,
      stripePendingPollTimeoutNs: 5_000_000_000,
      claimedTeleportRecheckDelays: [0.2, 0.2],
      superwall: superwall
    )
    #expect(await fresh.recoverPendingTeleport() == false)
    #expect(await fresh.recoverPendingTeleport() == false)
    #expect(network.teleportStatusRequests.count == 1)
    #expect(await fresh.waitForClaimedTeleportRecheck() == false)
    #expect(network.teleportStatusRequests.count == 3)
  }

  @Test("A claimed teleport whose checkout can't be read is kept for later")
  func claimedTeleport_checkoutCheckFails_isKept() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerTeleportOpen(teleport)
    network.teleportStatusResponses = [status("claimed")]
    network.checkoutStatusResponses = [.failure(NetworkError.unknown)]
    let fresh = makeRedeemer(storage: storage, network: network, superwall: superwall)

    #expect(await fresh.recoverPendingTeleport() == false)
    #expect(storage.get(PendingTeleportStorage.self) == teleport)
    #expect(network.pollRedemptionResultCallCount == 0)
  }

  @Test("A claimed teleport without a checkout is forgotten")
  func claimedTeleport_withoutCheckout_isForgotten() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerTeleportOpen(teleport)
    network.teleportStatusResponses = [status("claimed", checkoutContextId: nil)]
    let fresh = makeRedeemer(storage: storage, network: network, superwall: superwall)

    #expect(await fresh.recoverPendingTeleport() == false)
    #expect(network.checkoutStatusRequests.isEmpty)
    #expect(storage.get(PendingTeleportStorage.self) == nil)
  }

  @Test("A completed teleport without its checkout is forgotten")
  func completedTeleport_withoutCheckout_isForgotten() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    network.teleportStatusResponses = [status("completed", checkoutContextId: nil)]
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerTeleportOpen(teleport)
    let fresh = makeRedeemer(storage: storage, network: network, superwall: superwall)

    #expect(await fresh.recoverPendingTeleport() == false)
    #expect(storage.get(PendingTeleportStorage.self) == nil)
    #expect(network.pollRedemptionResultCallCount == 0)
  }

  @Test("A failed status check keeps the teleport for the next launch or foreground")
  func failedCheck_keepsTeleport() async {
    let (superwall, mockDelegate) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    network.teleportStatusResponses = [.failure(NetworkError.unknown)]
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerTeleportOpen(teleport)
    let fresh = makeRedeemer(storage: storage, network: network, superwall: superwall)

    #expect(await fresh.recoverPendingTeleport() == false)
    #expect(storage.get(PendingTeleportStorage.self) == teleport)
    #expect(await fresh.shouldShowStripeRecoveryLoadingOnPaywallOpen() == false)

    network.teleportStatusResponses = [status("completed")]
    network.pollRedemptionResultResponses = [redeemedResponse()]
    #expect(await fresh.recoverPendingTeleport() == true)
    #expect(mockDelegate.receivedResult?.code == "redemption_123")
  }

  @Test("A teleport older than its time limit is forgotten without a request")
  func expiredTeleport_isForgottenWithoutRequest() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerTeleportOpen(
      PendingTeleportState(
        teleportId: "tp_1",
        productId: "prod_1",
        openedAt: Date().addingTimeInterval(-PendingTeleportState.timeLimit - 1)
      )
    )

    #expect(await redeemer.recoverPendingTeleport() == false)
    #expect(network.teleportStatusRequests.isEmpty)
    #expect(storage.get(PendingTeleportStorage.self) == nil)
  }

  @Test("No stored teleport, no request")
  func noTeleport_noRequest() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)

    #expect(await redeemer.recoverPendingTeleport() == false)
    #expect(network.teleportStatusRequests.isEmpty)
  }

  @Test("A teleport still pending is kept for later, without holding a paywall or rechecking")
  func pendingTeleport_isKept() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    network.teleportStatusResponses = [status("pending", checkoutContextId: nil)]
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerTeleportOpen(teleport)
    let fresh = makeRedeemer(storage: storage, network: network, superwall: superwall)

    #expect(await fresh.recoverPendingTeleport() == false)
    #expect(await fresh.waitForClaimedTeleportRecheck() == false)

    #expect(storage.get(PendingTeleportStorage.self) == teleport)
    #expect(network.teleportStatusRequests.count == 1)
    #expect(network.pollRedemptionResultCallCount == 0)
    #expect(await fresh.shouldShowStripeRecoveryLoadingOnPaywallOpen() == false)

    // Paid later in Safari: the next launch or foreground finishes it.
    network.teleportStatusResponses = [status("completed")]
    network.pollRedemptionResultResponses = [redeemedResponse()]
    #expect(await fresh.recoverPendingTeleport() == true)
    #expect(storage.get(PendingTeleportStorage.self) == nil)
  }

  @Test("A repeated settlement of an older teleport keeps the newer one")
  func repeatedSettlement_keepsNewerTeleport() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    let newer = PendingTeleportState(teleportId: "tp_2", productId: "prod_offered")
    await redeemer.registerTeleportOpen(newer)

    network.pollRedemptionResultResponses = [redeemedResponse()]
    await redeemer.handleStripeCheckoutComplete(
      contextId: "ctx_1",
      productId: "prod_1",
      completion: .purchase(productId: "prod_1", shouldDismiss: true),
      settlingTeleportId: nil
    )
    #expect(storage.get(PendingTeleportStorage.self) == newer)

    await redeemer.handleStripeCheckoutAbandon(productId: "prod_1", settlingTeleportId: "tp_1")
    #expect(storage.get(PendingTeleportStorage.self) == newer)
  }

  @Test("A purchased link for a submitted checkout finishes it as the link says")
  func purchasedReturn_forSubmittedCheckout_takesLinkCompletion() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    network.pollRedemptionResultResponses = [.failure(NetworkError.unknown)]
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_1", productId: "prod_submitted")
    let attempts = storage.get(PendingStripeCheckoutPollStorage.self)?.remainingForegroundAttempts

    await redeemer.handlePurchasedReturn(purchase)

    let pending = storage.get(PendingStripeCheckoutPollStorage.self)
    #expect(pending?.productId == "prod_1")
    #expect(pending?.completion == .purchase(productId: "prod_1", shouldDismiss: true))
    #expect(pending.map { $0.remainingForegroundAttempts <= (attempts ?? 0) } == true)
  }

  @Test("A teleport the page settled itself isn't checked again")
  func pageSettledTeleport_isForgotten() async {
    let (superwall, _) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)

    await redeemer.registerTeleportOpen(teleport)
    await redeemer.handleStripeCheckoutAbandon(productId: "prod_1", settlingTeleportId: "tp_1")
    #expect(storage.get(PendingTeleportStorage.self) == nil)

    await redeemer.registerTeleportOpen(teleport)
    network.pollRedemptionResultResponses = [redeemedResponse()]
    await redeemer.handleStripeCheckoutComplete(
      contextId: "ctx_1",
      productId: "prod_1",
      completion: .purchase(productId: "prod_1", shouldDismiss: true),
      settlingTeleportId: "tp_1"
    )
    #expect(storage.get(PendingTeleportStorage.self) == nil)
    #expect(await redeemer.recoverPendingTeleport() == false)
    #expect(network.teleportStatusRequests.isEmpty)
  }

  @Test("A completed teleport the page already redeemed isn't redeemed again")
  func completedTeleport_afterPageRedeemed_redeemsOnce() async {
    let (superwall, mockDelegate) = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    network.pollRedemptionResultResponses = [redeemedResponse()]
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.handleStripeCheckoutComplete(
      contextId: "ctx_1",
      productId: "prod_1",
      completion: .purchase(productId: "prod_1", shouldDismiss: true)
    )
    // A teleport stored again afterwards (say by a second open) reads completed for that checkout.
    await redeemer.registerTeleportOpen(teleport)
    network.teleportStatusResponses = [status("completed")]

    #expect(await redeemer.recoverPendingTeleport() == true)
    #expect(network.pollRedemptionResultCallCount == 1)
    #expect(mockDelegate.willRedeemCallCount == 1)
  }

  @Test("Without a dismissal from the page, a recovered teleport finishes as a restore")
  func teleportPurchase_withoutDismissal_restores() {
    let stored = PendingTeleportState(teleportId: "tp_1", productId: "prod_offered")
    #expect(
      stored.purchase(checkoutContextId: "ctx_1", productId: nil)
        == PurchasedReturn(checkoutContextId: "ctx_1", productId: "prod_offered", completion: .restore)
    )
    #expect(stored.purchase(checkoutContextId: "ctx_1", productId: "").productId == "prod_offered")
  }

  // MARK: - Paywalls covered while loading

  private let pro = Entitlement(id: "pro", isActive: true, store: .stripe)

  private func entitlements(_ entitlements: [Entitlement]) -> EntitlementsResponse {
    EntitlementsResponse(
      customerInfo: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: entitlements)
    )
  }

  @Test("An entitlement that becomes active is an arrival; one already active or inactive isn't")
  func arrival_onlyForNewlyActiveEntitlements() {
    let inactivePro = Entitlement(id: "pro", isActive: false, store: .stripe)
    #expect(WebEntitlementsArrival(previousWebEntitlements: [], webEntitlements: [pro]) != nil)
    #expect(WebEntitlementsArrival(previousWebEntitlements: [inactivePro], webEntitlements: [pro]) != nil)
    #expect(WebEntitlementsArrival(previousWebEntitlements: [pro], webEntitlements: [pro]) == nil)
    #expect(WebEntitlementsArrival(previousWebEntitlements: [], webEntitlements: [inactivePro]) == nil)
    #expect(WebEntitlementsArrival(previousWebEntitlements: [pro], webEntitlements: []) == nil)
  }

  @Test("Only a paywall whose audience was evaluated before the entitlements arrived counts")
  func arrival_comparedWithAudienceEvaluation() throws {
    let arrivedAt = Date()
    let arrival = try #require(
      WebEntitlementsArrival(previousWebEntitlements: [], webEntitlements: [pro], arrivedAt: arrivedAt)
    )
    #expect(arrival.cameAfter(arrivedAt.addingTimeInterval(-1)))
    #expect(!arrival.cameAfter(arrivedAt.addingTimeInterval(1)))
    // A paywall with no placement, such as the debugger's, is never closed this way.
    #expect(!arrival.cameAfter(nil))
  }

  @Test("A poll that brings new entitlements records when they arrived")
  func poll_recordsArrival() async {
    let (superwall, _) = makeSuperwall()
    let network = makeNetwork()
    network.getEntitlementsResponse = entitlements([pro])
    let redeemer = makeRedeemer(storage: StorageMock(internalRedeemResponse: nil), network: network, superwall: superwall)

    let before = Date()
    await redeemer.pollWebEntitlements(isFirstTime: true)

    let arrival = await redeemer.lastWebEntitlementsArrival
    #expect(arrival != nil)
    #expect((arrival?.arrivedAt ?? .distantPast) >= before)
  }

  @Test("A refresh after a purchase, or a poll that brings nothing new, records no arrival")
  func refreshOrUnchangedPoll_recordsNoArrival() async {
    let (superwall, _) = makeSuperwall()
    let network = makeNetwork()
    network.getEntitlementsResponse = entitlements([pro])
    let redeemer = makeRedeemer(storage: StorageMock(internalRedeemResponse: nil), network: network, superwall: superwall)

    // After an in-app or custom store purchase: that purchase reports its own result.
    await redeemer.refreshWebEntitlements()
    #expect(await redeemer.lastWebEntitlementsArrival == nil)

    // Already active before this poll: the paywall was shown to a subscribed user.
    await redeemer.pollWebEntitlements(isFirstTime: true)
    #expect(await redeemer.lastWebEntitlementsArrival == nil)
  }

  @MainActor
  private func makeOpenedPaywall(
    evaluatedAt: Date?,
    registeredAt: Date = Date().addingTimeInterval(-10),
    hasPlacement: Bool = true,
    presented: Bool = true
  ) -> PaywallViewControllerMock {
    var paywall = Paywall.stub()
    paywall.products = [
      SuperwallKit.Product(
        name: "prod_pro",
        type: .stripe(.init(id: "prod_pro", trialDays: nil)),
        id: "prod_pro",
        entitlements: [Entitlement(id: "pro")]
      )
    ]
    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: paywall,
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: FakeWebView(
        isiOSAppOnMac: false,
        messageHandler: messageHandler,
        isOnDeviceCacheEnabled: true,
        factory: dependencyContainer
      ),
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil,
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    messageHandler.delegate = paywallVc
    let presentationInfo: PresentationInfo = hasPlacement
      ? .explicitTrigger(PlacementData(name: "session_start", parameters: [:], createdAt: registeredAt))
      : .fromIdentifier("paywall", freeTrialOverride: false)
    var request = dependencyContainer.makePresentationRequest(
      presentationInfo,
      isPaywallPresented: false,
      type: .presentation
    )
    request.audienceEvaluatedAt = evaluatedAt
    paywallVc.set(
      request: request,
      paywall: paywall,
      paywallStatePublisher: .init(),
      unsavedOccurrence: nil
    )
    if presented {
      _ = paywallVc.dispatch(.event(.presentationWillBegin(.init(isPresentedBySDK: true, claimId: nil))))
      _ = paywallVc.dispatch(.event(.presentationDidFinish))
    }
    return paywallVc
  }

  /// A redeemer whose poll just brought `pro`, which the paywall's product unlocks.
  private func makeRedeemerAfterArrival() async -> (WebEntitlementRedeemer, Superwall) {
    let (superwall, _) = makeSuperwall()
    dependencyContainer.entitlementsInfo.setEntitlementsFromConfig(["prod_pro": [pro]])
    let network = makeNetwork()
    network.getEntitlementsResponse = entitlements([pro])
    let redeemer = makeRedeemer(storage: StorageMock(internalRedeemResponse: nil), network: network, superwall: superwall)
    await redeemer.pollWebEntitlements(isFirstTime: true)
    superwall.subscriptionStatus = .active([pro])
    return (redeemer, superwall)
  }

  @Test("A paywall whose audience was evaluated before its entitlements arrived closes when it opens")
  func paywallEvaluatedBeforeArrival_closesOnOpen() async {
    let evaluatedAt = Date()
    let (redeemer, _) = await makeRedeemerAfterArrival()
    let paywallVc = await makeOpenedPaywall(evaluatedAt: evaluatedAt)

    #expect(await redeemer.dismissPaywallCoveredWhileLoading(paywallVc) == true)
  }

  @Test("A paywall whose audience was evaluated after the entitlements arrived was shown on purpose")
  func paywallEvaluatedAfterArrival_stays() async {
    let (redeemer, _) = await makeRedeemerAfterArrival()
    let paywallVc = await makeOpenedPaywall(evaluatedAt: Date().addingTimeInterval(1))

    #expect(await redeemer.dismissPaywallCoveredWhileLoading(paywallVc) == false)
  }

  @Test("A launch placement registered before the arrival but evaluated after it stays")
  func paywallRegisteredBeforeButEvaluatedAfterArrival_stays() async {
    // Registered at launch, then held by the launch waits while the entitlements arrived, so
    // its audience saw a subscribed user (an upgrade offer, say).
    let registeredAt = Date()
    let (redeemer, _) = await makeRedeemerAfterArrival()
    let paywallVc = await makeOpenedPaywall(
      evaluatedAt: Date().addingTimeInterval(1),
      registeredAt: registeredAt
    )

    #expect(await redeemer.dismissPaywallCoveredWhileLoading(paywallVc) == false)
  }

  @Test("A paywall the debugger opened, or one not on screen, stays")
  func paywallWithoutPlacementOrNotOnScreen_stays() async {
    let evaluatedAt = Date()
    let (redeemer, _) = await makeRedeemerAfterArrival()

    let debuggerPaywall = await makeOpenedPaywall(evaluatedAt: evaluatedAt, hasPlacement: false)
    #expect(await redeemer.dismissPaywallCoveredWhileLoading(debuggerPaywall) == false)

    let notEvaluated = await makeOpenedPaywall(evaluatedAt: nil)
    #expect(await redeemer.dismissPaywallCoveredWhileLoading(notEvaluated) == false)

    let notOpened = await makeOpenedPaywall(evaluatedAt: evaluatedAt, presented: false)
    #expect(await redeemer.dismissPaywallCoveredWhileLoading(notOpened) == false)
  }

  @Test("Entitlements that don't cover the paywall's products leave it up")
  func uncoveredPaywall_stays() async {
    let evaluatedAt = Date()
    let (redeemer, _) = await makeRedeemerAfterArrival()
    dependencyContainer.entitlementsInfo.setEntitlementsFromConfig([
      "prod_pro": [Entitlement(id: "pro_plus", isActive: false, store: .stripe)]
    ])
    let paywallVc = await makeOpenedPaywall(evaluatedAt: evaluatedAt)

    #expect(await redeemer.dismissPaywallCoveredWhileLoading(paywallVc) == false)
  }

  @Test("Without any arrival this session, nothing is closed")
  func noArrival_nothingClosed() async {
    let (superwall, _) = makeSuperwall()
    let redeemer = makeRedeemer(storage: StorageMock(internalRedeemResponse: nil), network: makeNetwork(), superwall: superwall)
    let paywallVc = await makeOpenedPaywall(evaluatedAt: Date())

    #expect(await redeemer.dismissPaywallCoveredWhileLoading(paywallVc) == false)
  }
}
