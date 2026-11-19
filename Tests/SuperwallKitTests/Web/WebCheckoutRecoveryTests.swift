//
//  WebCheckoutRecoveryTests.swift
//  SuperwallKit
//
//  Created by Superwall on 19/11/2026.
//
// swiftlint:disable all

import Testing
@testable import SuperwallKit
import Foundation

/// Lets a test act while an event is being tracked.
private final class EventHookDelegate: SuperwallDelegate {
  var onEvent: ((SuperwallEvent) -> Void)?

  func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
    onEvent?(eventInfo.event)
  }
}

/// A web checkout that's paid for is finished once, the way its paywall asked, whichever of
/// the return link, the paywall page and the background checks hears about it first.
@Suite(.serialized)
struct WebCheckoutRecoveryTests {
  /// Paywalls and redeemers hold their dependencies unowned and start tasks that outlive the
  /// test, so what they depend on lives for the whole process.
  private static var retained: [AnyObject] = []

  let dependencyContainer: DependencyContainer

  init() {
    let container = DependencyContainer()
    Self.retained.append(container)
    dependencyContainer = container
    container.storage.delete(PendingStripeCheckoutPollStorage.self)
    container.storage.delete(PendingTeleportStorage.self)
  }

  // MARK: - Helpers

  private let pro = Entitlement(id: "pro", isActive: true, store: .stripe)

  private let teleport = PendingTeleportState(
    teleportId: "tp_1",
    productId: "prod_offered",
    shouldDismiss: true
  )

  private func makeRedeemer(
    storage: StorageMock = StorageMock(internalRedeemResponse: nil),
    network: NetworkMock,
    superwall: Superwall
  ) -> WebEntitlementRedeemer {
    let redeemer = WebEntitlementRedeemer(
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
    Self.retained.append(redeemer)
    Self.retained.append(storage)
    Self.retained.append(network)
    return redeemer
  }

  private func makeNetwork() -> NetworkMock {
    let options = dependencyContainer.makeSuperwallOptions()
    options.paywalls.shouldShowWebPurchaseConfirmationAlert = false
    return NetworkMock(options: options, factory: dependencyContainer)
  }

  private func redeemedResponse(
    code: String = "redemption_123",
    entitlements: Set<Entitlement> = [.stub()]
  ) -> Result<RedeemResponse, Error> {
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

  private var pendingResponse: Result<RedeemResponse, Error> {
    .success(RedeemResponse(results: [], customerInfo: .blank(), status: .pending))
  }

  private func entitlements(_ entitlements: [Entitlement]) -> EntitlementsResponse {
    EntitlementsResponse(
      customerInfo: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: entitlements)
    )
  }

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

  private func makeSuperwall(
    delegate: SuperwallDelegate = MockSuperwallDelegate()
  ) -> Superwall {
    let superwall = Superwall(dependencyContainer: dependencyContainer)
    let delegateAdapter = SuperwallDelegateAdapter()
    delegateAdapter.swiftDelegate = delegate
    superwall.delegate = delegate
    dependencyContainer.delegateAdapter = delegateAdapter
    Self.retained.append(superwall)
    Self.retained.append(delegate)
    Self.retained.append(delegateAdapter)
    return superwall
  }

  /// A paywall selling `prod_pro`, which the config says unlocks `pro` once
  /// ``mapProductToPro()`` is called.
  @MainActor
  private func makePaywall(
    redeemer: WebEntitlementRedeemer,
    evaluatedAt: Date? = nil,
    seenByAudience: Set<String>? = nil,
    presented: Bool = true,
    onScreenAs key: String? = nil
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
      webEntitlementRedeemer: redeemer,
      cache: nil,
      paywallArchiveManager: nil,
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    Self.retained.append(paywallVc)
    messageHandler.delegate = paywallVc
    paywallVc.webView.delegate = paywallVc
    // The page's first load, which comes before anything the page can report.
    paywallVc.loadViewIfNeeded()
    var request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(
        PlacementData(name: "session_start", parameters: [:], createdAt: Date().addingTimeInterval(-10))
      ),
      isPaywallPresented: false,
      type: .presentation
    )
    request.audienceEvaluatedAt = evaluatedAt
    request.entitlementIdsSeenByAudience = seenByAudience
    paywallVc.set(
      request: request,
      paywall: paywall,
      paywallStatePublisher: .init(),
      unsavedOccurrence: nil
    )
    if presented {
      present(paywallVc)
    }
    if let key {
      let cache = dependencyContainer.paywallManager.cache
      cache.save(paywallVc, forKey: key)
      cache.activePaywallVcKey = key
    }
    return paywallVc
  }

  /// Puts the paywall on screen, as a new presentation.
  @MainActor
  @discardableResult
  private func present(_ paywallVc: PaywallViewController) -> UUID {
    let presentation = PaywallViewState.Presentation(isPresentedBySDK: true, claimId: nil)
    _ = paywallVc.dispatch(.event(.presentationWillBegin(presentation)))
    _ = paywallVc.dispatch(.event(.presentationDidFinish))
    return presentation.id
  }

  /// Takes the paywall off screen and finishes its dismissal.
  @MainActor
  private func dismiss(_ paywallVc: PaywallViewController) {
    guard case .dismissalStarted(let id?) = paywallVc.dispatch(.didDisappear) else {
      return
    }
    _ = paywallVc.dispatch(.finishDismissal(id))
  }

  private func mapProductToPro() {
    dependencyContainer.entitlementsInfo.setEntitlementsFromConfig(["prod_pro": [pro]])
  }

  @discardableResult
  private func waitUntil(
    timeout: TimeInterval = 2,
    _ condition: () async -> Bool
  ) async -> Bool {
    let end = Date().addingTimeInterval(timeout)
    while Date() < end {
      if await condition() {
        return true
      }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return await condition()
  }

  @MainActor
  private func dismissal(of paywallVc: PaywallViewController) -> PaywallViewState.Dismissal? {
    paywallVc.store.read { $0.activePresentation?.dismissal }
  }

  @MainActor
  private func completedPurchase(on paywallVc: PaywallViewController) -> String? {
    paywallVc.store.read { $0.completedPurchase?.productIdentifier }
  }

  // MARK: - Paywalls covered while loading

  @Test("A paywall evaluated before a recovered checkout was redeemed closes when it opens")
  func redemptionWithoutPaywall_closesPaywallEvaluatedBeforeIt() async {
    let superwall = makeSuperwall()
    mapProductToPro()
    let network = makeNetwork()
    network.pollRedemptionResultResponses = [redeemedResponse(entitlements: [pro])]
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    // The launch placement's audience sees a user who isn't subscribed yet.
    let evaluatedAt = Date()
    try? await Task.sleep(nanoseconds: 5_000_000)
    // The return link's checkout is redeemed before any paywall is on screen.
    await redeemer.handlePurchasedReturn(
      PurchasedReturn(
        checkoutContextId: "ctx_1",
        productId: "prod_pro",
        completion: .purchase(productId: "prod_pro", shouldDismiss: true)
      )
    )
    #expect(network.pollRedemptionResultCallCount == 1)
    superwall.subscriptionStatus = .active([pro])

    let paywallVc = await makePaywall(redeemer: redeemer, evaluatedAt: evaluatedAt)
    #expect(await redeemer.dismissPaywallCoveredWhileLoading(paywallVc) == true)
  }

  @Test("New entitlements that the paywall doesn't sell don't close a paywall shown to a subscriber")
  func unrelatedArrival_leavesPaywallShownToSubscriber() async {
    let superwall = makeSuperwall()
    mapProductToPro()
    let other = Entitlement(id: "other", isActive: true, store: .stripe)
    // `pro` was active before this session's poll, so the audience saw it.
    let storage = StorageMock(
      internalRedeemResponse: RedeemResponse(
        results: [],
        customerInfo: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [pro])
      )
    )
    let network = makeNetwork()
    network.getEntitlementsResponse = entitlements([pro, other])
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)

    let evaluatedAt = Date()
    try? await Task.sleep(nanoseconds: 5_000_000)
    await redeemer.pollWebEntitlements(isFirstTime: true)
    #expect(await redeemer.lastWebEntitlementsArrival != nil)
    superwall.subscriptionStatus = .active([pro, other])

    // An upgrade offer for `pro`, shown to the subscriber on purpose.
    let paywallVc = await makePaywall(redeemer: redeemer, evaluatedAt: evaluatedAt)
    #expect(await redeemer.dismissPaywallCoveredWhileLoading(paywallVc) == false)
    #expect(await dismissal(of: paywallVc) == nil)
  }

  @Test("An entitlement the audience saw active doesn't close the paywall when it arrives again")
  func entitlementSeenByAudience_leavesPaywall() async {
    let superwall = makeSuperwall()
    mapProductToPro()
    let network = makeNetwork()
    network.getEntitlementsResponse = entitlements([pro])
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    let evaluatedAt = Date()
    try? await Task.sleep(nanoseconds: 5_000_000)
    await redeemer.pollWebEntitlements(isFirstTime: true)
    superwall.subscriptionStatus = .active([pro])

    // `pro` was already active from the App Store when the audience was evaluated.
    let shownOnPurpose = await makePaywall(
      redeemer: redeemer,
      evaluatedAt: evaluatedAt,
      seenByAudience: ["pro"]
    )
    #expect(await redeemer.dismissPaywallCoveredWhileLoading(shownOnPurpose) == false)

    // The same paywall, let through while `pro` was still on its way.
    let letThrough = await makePaywall(redeemer: redeemer, evaluatedAt: evaluatedAt, seenByAudience: [])
    #expect(await redeemer.dismissPaywallCoveredWhileLoading(letThrough) == true)
  }

  @Test("A paywall already closing as purchased isn't closed again as restored when it opens")
  func paywallAlreadyClosing_keepsItsResult() async {
    let superwall = makeSuperwall()
    mapProductToPro()
    let network = makeNetwork()
    network.getEntitlementsResponse = entitlements([pro])
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    let evaluatedAt = Date()
    try? await Task.sleep(nanoseconds: 5_000_000)
    await redeemer.pollWebEntitlements(isFirstTime: true)
    superwall.subscriptionStatus = .active([pro])

    let paywallVc = await makePaywall(redeemer: redeemer, evaluatedAt: evaluatedAt)
    // A recovered checkout just finished on it as a purchase.
    let purchased = PaywallViewState.Dismissal(
      result: .purchased(StoreProduct.blank(productIdentifier: "prod_pro")),
      closeReason: .systemLogic
    )
    _ = await paywallVc.dispatch(.event(.dismissRequested(purchased)))

    #expect(await redeemer.dismissPaywallCoveredWhileLoading(paywallVc) == false)
    #expect(await dismissal(of: paywallVc) == purchased)
  }

  @Test("A poll doesn't close a paywall as restored once it's closing as purchased")
  func poll_leavesPaywallAlreadyClosing() async {
    let superwall = makeSuperwall()
    mapProductToPro()
    let network = makeNetwork()
    network.getEntitlementsResponse = entitlements([pro])
    let redeemer = makeRedeemer(network: network, superwall: superwall)
    let paywallVc = await makePaywall(redeemer: redeemer, onScreenAs: "closing")
    let purchased = PaywallViewState.Dismissal(
      result: .purchased(StoreProduct.blank(productIdentifier: "prod_pro")),
      closeReason: .systemLogic
    )
    _ = await paywallVc.dispatch(.event(.dismissRequested(purchased)))

    await redeemer.pollWebEntitlements(isFirstTime: true)

    #expect(await dismissal(of: paywallVc) == purchased)
  }

  @Test("A covered paywall that was closed and shown again meanwhile is left alone")
  func coveredPaywall_shownAgainWhileRestoring_staysUp() async {
    let delegate = EventHookDelegate()
    let superwall = makeSuperwall(delegate: delegate)
    mapProductToPro()
    let network = makeNetwork()
    network.getEntitlementsResponse = entitlements([pro])
    let redeemer = makeRedeemer(network: network, superwall: superwall)

    let evaluatedAt = Date()
    try? await Task.sleep(nanoseconds: 5_000_000)
    await redeemer.pollWebEntitlements(isFirstTime: true)
    superwall.subscriptionStatus = .active([pro])

    let paywallVc = await makePaywall(redeemer: redeemer, evaluatedAt: evaluatedAt, presented: false)
    let first = await present(paywallVc)
    let second = PaywallViewState.Presentation(isPresentedBySDK: true, claimId: nil)
    // While the restore is tracked, the user closes the paywall and the app shows it again
    // for another placement.
    delegate.onEvent = { event in
      guard case .restoreComplete = event else {
        return
      }
      _ = paywallVc.dispatch(.event(.disappeared))
      _ = paywallVc.dispatch(.event(.dismissalFinished(first)))
      _ = paywallVc.dispatch(.event(.presentationWillBegin(second)))
      _ = paywallVc.dispatch(.event(.presentationDidFinish))
    }

    await redeemer.dismissPaywallCoveredWhileLoading(paywallVc)

    let (activeId, activeDismissal) = await MainActor.run {
      paywallVc.store.read { ($0.activePresentation?.id, $0.activePresentation?.dismissal) }
    }
    #expect(activeId == second.id)
    #expect(activeDismissal == nil)
  }

  // MARK: - The return link

  @Test("A purchased link for a checkout that's been pending past its time limit still polls")
  func purchasedLink_forCheckoutPendingPastItsTimeout_stillPolls() async {
    let mockDelegate = MockSuperwallDelegate()
    let superwall = makeSuperwall(delegate: mockDelegate)
    let storage = StorageMock(internalRedeemResponse: nil)
    // Submitted in the embedded checkout, then approved in a bank app for longer than the
    // pending checkout's time limit.
    storage.save(
      PendingStripeCheckoutPollState(
        checkoutContextId: "ctx_1",
        productId: "prod_submitted",
        updatedAt: Date().addingTimeInterval(-90)
      ),
      forType: PendingStripeCheckoutPollStorage.self
    )
    let network = makeNetwork()
    network.pollRedemptionResultResponses = [redeemedResponse()]
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)

    await redeemer.handlePurchasedReturn(
      PurchasedReturn(checkoutContextId: "ctx_1", productId: "", completion: .restore)
    )

    #expect(network.pollRedemptionResultCallCount == 1)
    #expect(mockDelegate.receivedResult?.code == "redemption_123")
  }

  @Test("A purchased link without a product never finishes as a purchase of nothing")
  func purchasedLink_withoutProduct_restores() async {
    let url = URL(
      string: "myapp://superwall/return?reason=purchased&checkout_context_id=ctx_1&should_dismiss=true"
    )!
    let link = url.superwallPurchasedReturn
    #expect(link?.completion == .restore)

    // Nor does a teleport nothing named a product for.
    let unnamed = PendingTeleportState(teleportId: "tp_1", productId: "", shouldDismiss: true)
    #expect(unnamed.purchase(checkoutContextId: "ctx_1", productId: nil).completion == .restore)

    // And the product a pending checkout was submitted with is kept.
    let superwall = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    network.pollRedemptionResultResponses = [.failure(NetworkError.unknown)]
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_1", productId: "prod_submitted")
    if let link {
      await redeemer.handlePurchasedReturn(link)
    }
    let pending = storage.get(PendingStripeCheckoutPollStorage.self)
    #expect(pending?.productId == "prod_submitted")
    #expect(pending?.completion == .restore)
  }

  @Test("A link that says how to finish reaches a poll already in flight for its checkout")
  func linkDuringPoll_finishesAsTheLinkSays() async {
    let superwall = makeSuperwall()
    let network = makeNetwork()
    network.pollRedemptionResultResponses = Array(repeating: pendingResponse, count: 20)
      + [redeemedResponse()]
    let redeemer = makeRedeemer(network: network, superwall: superwall)
    let paywallVc = await makePaywall(redeemer: redeemer, onScreenAs: "in-flight")
    // The embedded checkout was submitted, which can't say how to finish.
    await redeemer.registerStripeCheckoutSubmit(contextId: "ctx_1", productId: "prod_1")

    let poll = Task {
      await redeemer.pollPendingStripeCheckoutOnForegroundIfNeeded()
    }
    await waitUntil { network.pollRedemptionResultCallCount > 0 }
    await redeemer.handlePurchasedReturn(
      PurchasedReturn(
        checkoutContextId: "ctx_1",
        productId: "prod_1",
        completion: .purchase(productId: "prod_1", shouldDismiss: false)
      )
    )
    await poll.value

    #expect(network.pollRedemptionResultCallCount == 21)
    #expect(await completedPurchase(on: paywallVc) == "prod_1")
  }

  @Test("A link that doesn't say how to finish leaves the purchase to the page that's still on screen")
  func linkWithoutCompletion_waitsForThePageOnScreen() async {
    let superwall = makeSuperwall()
    let network = makeNetwork()
    network.pollRedemptionResultResponses = [redeemedResponse()]
    let redeemer = makeRedeemer(network: network, superwall: superwall)
    let paywallVc = await makePaywall(redeemer: redeemer, onScreenAs: "warm-return")
    // The paywall on screen opened the teleport, and its page is still there.
    await redeemer.registerTeleportOpen(teleport)

    let link = Task {
      await redeemer.handlePurchasedReturn(
        PurchasedReturn(checkoutContextId: "ctx_1", productId: "", completion: .restore)
      )
    }
    // The link is handled first, then the page reports the purchase, saying how to finish it.
    await waitUntil(timeout: 0.2) { network.pollRedemptionResultCallCount > 0 }
    await redeemer.handleStripeCheckoutComplete(
      contextId: "ctx_1",
      productId: "prod_1",
      completion: .purchase(productId: "prod_1", shouldDismiss: false),
      settlingTeleportId: "tp_1"
    )
    await link.value

    #expect(network.pollRedemptionResultCallCount == 1)
    #expect(await completedPurchase(on: paywallVc) == "prod_1")
  }

  // MARK: - Stored teleports

  @Test("A paid teleport is kept until its checkout is redeemed")
  func paidTeleport_notYetRedeemed_isKept() async {
    let mockDelegate = MockSuperwallDelegate()
    let superwall = makeSuperwall(delegate: mockDelegate)
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let before = makeRedeemer(storage: storage, network: network, superwall: superwall)
    await before.registerTeleportOpen(teleport)

    // Read paid on launch, but the redemption poll fails, as it can before the network is up.
    network.teleportStatusResponses = [status("completed")]
    let launch = makeRedeemer(storage: storage, network: network, superwall: superwall)
    #expect(await launch.recoverPendingTeleport() == true)
    #expect(storage.get(PendingTeleportStorage.self) == teleport)

    // The pending checkout runs out of time before the app is opened again.
    storage.delete(PendingStripeCheckoutPollStorage.self)

    network.teleportStatusResponses = [status("completed")]
    network.pollRedemptionResultResponses = [redeemedResponse()]
    let later = makeRedeemer(storage: storage, network: network, superwall: superwall)
    #expect(await later.recoverPendingTeleport() == true)
    #expect(mockDelegate.receivedResult?.code == "redemption_123")
    #expect(storage.get(PendingTeleportStorage.self) == nil)
  }

  @Test("A teleport whose paywall was closed is checked in the background, whatever is on screen")
  func teleportWhosePaywallWasClosed_isChecked() async {
    let superwall = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    let paywallVc = await makePaywall(redeemer: redeemer)
    await paywallVc.teleportDidOpen(teleport)
    await waitUntil { storage.get(PendingTeleportStorage.self) == teleport }

    // The paywall that teleported is closed, and another one is shown.
    await dismiss(paywallVc)
    _ = await makePaywall(redeemer: redeemer, onScreenAs: "another")

    network.teleportStatusResponses = Array(repeating: status("pending"), count: 200)
    let wasChecked = await waitUntil(timeout: 1) {
      await redeemer.recoverPendingTeleport()
      return !network.teleportStatusRequests.isEmpty
    }
    #expect(wasChecked)
  }

  @Test("A teleport whose page was reloaded is checked in the background")
  func teleportWhosePageReloaded_isChecked() async {
    let superwall = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    let paywallVc = await makePaywall(redeemer: redeemer, onScreenAs: "reloaded")
    await paywallVc.teleportDidOpen(teleport)
    await waitUntil { storage.get(PendingTeleportStorage.self) == teleport }

    // iOS ended the page's process while the app was in the background, so it loads again
    // and no longer knows about the teleport.
    await MainActor.run {
      paywallVc.webView.webViewWebContentProcessDidTerminate(paywallVc.webView)
    }

    network.teleportStatusResponses = Array(repeating: status("pending"), count: 200)
    let wasChecked = await waitUntil(timeout: 1) {
      await redeemer.recoverPendingTeleport()
      return !network.teleportStatusRequests.isEmpty
    }
    #expect(wasChecked)
  }

  @Test("Entitlements that become active while the audience is evaluated count as seen by it")
  func audienceSnapshot_includesEntitlementsActivatedDuringEvaluation() async {
    var request = DependencyContainer().makePresentationRequest(
      .explicitTrigger(PlacementData(name: "session_start", parameters: [:], createdAt: Date())),
      isPaywallPresented: false,
      type: .presentation
    )
    var active: Set<String> = []
    var arrivedAt: Date?

    let outcome = await Superwall.evaluatingAudience(
      of: &request,
      activeEntitlementIds: { active },
      evaluate: { _ in
        // `pro` arrives while the audience builds its attributes, so the audience sees it.
        active = ["pro"]
        arrivedAt = Date()
        return "evaluated"
      }
    )

    #expect(outcome == "evaluated")
    #expect(request.entitlementIdsSeenByAudience == ["pro"])
    // Timed once evaluation is done, so the arrival comes before it and isn't counted again.
    let evaluatedAt = request.audienceEvaluatedAt ?? .distantPast
    #expect(evaluatedAt >= (arrivedAt ?? .distantFuture))
  }

  @Test("A checkout abandoned in a later presentation keeps an earlier presentation's teleport")
  func abandonInLaterPresentation_keepsEarlierTeleport() async {
    let mockDelegate = MockSuperwallDelegate()
    let superwall = makeSuperwall(delegate: mockDelegate)
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    let paywallVc = await makePaywall(redeemer: redeemer)
    // The user teleports, comes back without paying and closes the paywall. The checkout is
    // still open in Safari.
    await paywallVc.teleportDidOpen(teleport)
    await waitUntil { storage.get(PendingTeleportStorage.self) == teleport }
    await dismiss(paywallVc)

    // The paywall is shown again, and the user opens and closes its embedded checkout.
    await present(paywallVc)
    await paywallVc.handleStripeCheckoutAbandon(checkoutContextId: "ctx_embedded", productId: "prod_1")
    let wasAbandoned = await waitUntil {
      mockDelegate.eventsReceived.contains {
        if case .transactionAbandon = $0 {
          return true
        }
        return false
      }
    }
    #expect(wasAbandoned)

    #expect(storage.get(PendingTeleportStorage.self) == teleport)
  }

  @Test("An embedded checkout abandoned after a teleport, on the same paywall, keeps the teleport")
  func embeddedAbandonAfterTeleport_keepsTeleport() async {
    let mockDelegate = MockSuperwallDelegate()
    let superwall = makeSuperwall(delegate: mockDelegate)
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    let paywallVc = await makePaywall(redeemer: redeemer)
    // The user teleports and comes back without paying. The checkout is still open in Safari.
    await paywallVc.teleportDidOpen(teleport)
    await waitUntil { storage.get(PendingTeleportStorage.self) == teleport }

    // On the same paywall, they open and close the embedded checkout of another product.
    await paywallVc.handleStripeCheckoutStart(checkoutContextId: "ctx_embedded")
    await paywallVc.handleStripeCheckoutAbandon(checkoutContextId: "ctx_embedded", productId: "prod_2")
    let wasAbandoned = await waitUntil {
      mockDelegate.eventsReceived.contains {
        if case .transactionAbandon = $0 {
          return true
        }
        return false
      }
    }
    #expect(wasAbandoned)
    #expect(storage.get(PendingTeleportStorage.self) == teleport)

    // The page has moved on to another checkout, so the teleport is checked in the background.
    _ = await makePaywall(redeemer: redeemer, onScreenAs: "same paywall")
    network.teleportStatusResponses = Array(repeating: status("pending"), count: 200)
    let wasChecked = await waitUntil(timeout: 1) {
      await redeemer.recoverPendingTeleport()
      return !network.teleportStatusRequests.isEmpty
    }
    #expect(wasChecked)
  }

  @Test("A repeated report of an older checkout keeps the teleport the same paywall opened since")
  func repeatedCompletion_keepsNewerTeleportOfSamePaywall() async {
    let superwall = makeSuperwall()
    let storage = StorageMock(internalRedeemResponse: nil)
    let network = makeNetwork()
    let redeemer = makeRedeemer(storage: storage, network: network, superwall: superwall)
    let paywallVc = await makePaywall(redeemer: redeemer)

    // The first teleport's checkout is reported complete, which settles that teleport.
    let older = PendingTeleportState(teleportId: "tp_older", productId: "prod_1")
    await paywallVc.teleportDidOpen(older)
    await waitUntil { storage.get(PendingTeleportStorage.self) == older }
    await paywallVc.handleStripeCheckoutComplete(
      checkoutContextId: "ctx_older",
      productId: "prod_1",
      shouldDismiss: nil
    )
    await waitUntil { network.pollRedemptionResultCallCount == 1 }
    #expect(storage.get(PendingTeleportStorage.self) == nil)

    // A second teleport is opened, then the page reports the first checkout again.
    await paywallVc.teleportDidOpen(teleport)
    await waitUntil { storage.get(PendingTeleportStorage.self) == teleport }
    await paywallVc.handleStripeCheckoutComplete(
      checkoutContextId: "ctx_older",
      productId: "prod_1",
      shouldDismiss: nil
    )
    await waitUntil { network.pollRedemptionResultCallCount == 2 }
    // The redeemer has handled the repeat by the time its poll has failed.
    try? await Task.sleep(nanoseconds: 50_000_000)

    #expect(storage.get(PendingTeleportStorage.self) == teleport)
  }

  // MARK: - Requests

  @Test("The teleport and checkout status requests give up quickly")
  func statusRequests_retryLittle() {
    let teleportStatus = Endpoint<EndpointKinds.SubscriptionsAPI, TeleportStatusResponse>
      .teleportStatus(request: TeleportStatusRequest(teleportId: "tp_1"))
    let checkoutStatus = Endpoint<EndpointKinds.SubscriptionsAPI, CheckoutStatusResponse>
      .checkoutStatus(request: CheckoutStatusRequest(checkoutId: "ctx_1"))
    // The foreground polls wait behind these, so they can't take the default six retries.
    #expect(teleportStatus.retryCount <= 2)
    #expect(checkoutStatus.retryCount <= 2)
  }
}
