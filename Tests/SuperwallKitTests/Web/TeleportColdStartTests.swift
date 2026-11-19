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
}
