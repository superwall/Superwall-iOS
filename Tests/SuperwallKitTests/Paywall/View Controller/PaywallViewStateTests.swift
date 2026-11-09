//
//  PaywallViewStateTests.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//
// swiftlint:disable all

import Combine
import Foundation
import Testing
import UIKit
@testable import SuperwallKit

private let container = DependencyContainer()

private func makeRequest() -> PresentationRequest {
  container.makePresentationRequest(
    .implicitTrigger(PlacementData(name: "placement", parameters: [:], createdAt: Date())),
    isDebuggerLaunched: false,
    isPaywallPresented: false,
    type: .presentation
  )
}

private func makeClaim(
  paywall: Paywall = .stub(),
  occurrence: TriggerAudienceOccurrence? = nil
) -> PaywallViewState.Claim {
  PaywallViewState.Claim(request: makeRequest(), paywall: paywall, unsavedOccurrence: occurrence)
}

private func reduce(_ state: PaywallViewState, _ updates: PaywallViewUpdate...) -> PaywallViewState {
  updates.reduce(state) { $1.reduce($0) }
}

/// A state whose paywall is on screen, for the claim `claim`.
private func presentedState(claim: PaywallViewState.Claim = makeClaim()) -> PaywallViewState {
  var state = PaywallViewState(paywall: .stub())
  state = reduce(
    state,
    .claimed(claim, isHandedOut: false),
    .presentationWillBegin(.init(isPresentedBySDK: true, claimId: claim.id)),
    .presentationDidFinish
  )
  return state
}

// MARK: - Reducers

@Suite("PaywallViewUpdate loading")
struct PaywallViewLoadingTests {
  @Test(
    "Each loading change writes the right state, or leaves it alone",
    arguments: [
      (PaywallLoadingChange.webViewLoadStarted, PaywallLoadingState.ready, PaywallLoadingState?.some(.loadingURL)),
      (.webContentLoaded, .loadingURL, .ready),
      (.webContentLoaded, .manualLoading, nil),
      (.purchaseStarted, .ready, .loadingPurchase),
      (.manualLoadingStarted, .ready, .manualLoading),
      (.finished, .loadingPurchase, .ready),
      (.finished, .ready, .ready),
      (.spinnerRequested, .ready, .manualLoading),
      (.spinnerRequested, .loadingURL, nil),
      (.spinnerDismissed, .manualLoading, .ready),
      (.spinnerDismissed, .loadingPurchase, .ready),
      (.spinnerDismissed, .loadingURL, nil),
      (.manualLoadingEnded, .manualLoading, .ready),
      (.manualLoadingEnded, .loadingPurchase, nil)
    ]
  )
  func loadingChange(
    change: PaywallLoadingChange,
    from current: PaywallLoadingState,
    expected: PaywallLoadingState?
  ) {
    var state = PaywallViewState(paywall: .stub())
    state.loadingState = current
    let after = PaywallViewUpdate.loading(change).reduce(state)
    #expect(after.loadingState == (expected ?? current))
    #expect(after.loadingStateWrites == (expected == nil ? 0 : 1))
  }

  @Test("Starting a web view load records only the first start, and writes the loading state")
  func webViewLoadStarted() {
    let first = Date(timeIntervalSince1970: 1)
    let state = reduce(
      PaywallViewState(paywall: .stub()),
      .webViewLoadStarted(first),
      .webViewLoadStarted(Date(timeIntervalSince1970: 2))
    )
    #expect(state.paywall.webviewLoadingInfo.startAt == first)
    #expect(state.loadingState == .loadingURL)
    #expect(state.loadingStateWrites == 2)
  }

  @Test("Page load times, the paywall.js version, the shimmer and the page state are recorded")
  func paywallRecords() {
    let ended = Date(timeIntervalSince1970: 3)
    let failed = Date(timeIntervalSince1970: 4)
    let shimmerStart = Date(timeIntervalSince1970: 5)
    let shimmerEnd = Date(timeIntervalSince1970: 6)
    let state = reduce(
      PaywallViewState(paywall: .stub()),
      .webViewLoadEnded(ended),
      .webViewLoadFailed(failed),
      .paywallJSVersionReceived("2"),
      .shimmerStarted(shimmerStart),
      .shimmerEnded(shimmerEnd),
      .pageStateSaved(["key": "value"])
    )
    #expect(state.paywall.webviewLoadingInfo.endAt == ended)
    #expect(state.paywall.webviewLoadingInfo.failAt == failed)
    #expect(state.paywall.paywalljsVersion == "2")
    #expect(state.paywall.shimmerLoadingInfo.startAt == shimmerStart)
    #expect(state.paywall.shimmerLoadingInfo.endAt == shimmerEnd)
    #expect(state.paywall.state["key"] as? String == "value")
    #expect(state.loadingStateWrites == 0)
  }

  @Test("Replacing the paywall swaps it whole")
  func paywallReplaced() {
    var other = Paywall.stub()
    other.cacheKey = "other"
    let state = PaywallViewUpdate.paywallReplaced(other).reduce(PaywallViewState(paywall: .stub()))
    #expect(state.paywall.cacheKey == "other")
  }

  @Test("The presentation style follows an override, else the paywall's, and an embedded popup fills the view")
  func presentationStyle() {
    let start = PaywallViewState(paywall: .stub())
    let overridden = PaywallViewUpdate.presentationStyleChosen(override: .push).reduce(start)
    #expect(overridden.presentationStyle == .push)
    let none = PaywallViewUpdate.presentationStyleChosen(override: PaywallPresentationStyle.none)
      .reduce(overridden)
    #expect(none.presentationStyle == start.paywall.presentation.style)
    let noOverride = PaywallViewUpdate.presentationStyleChosen(override: nil).reduce(overridden)
    #expect(noOverride.presentationStyle == start.paywall.presentation.style)

    var popup = start
    popup.presentationStyle = .popup(height: 50, width: 50, cornerRadius: 10)
    #expect(PaywallViewUpdate.embedded.reduce(popup).presentationStyle == .fullscreen)
    #expect(PaywallViewUpdate.embedded.reduce(overridden).presentationStyle == .push)
  }
}

@Suite("PaywallViewUpdate claims")
struct PaywallViewClaimTests {
  @Test("A claim binds its request and occurrence, and the request and occurrence are read from it")
  func claimed() {
    let occurrence = TriggerAudienceOccurrence.stub()
    let claim = makeClaim(occurrence: occurrence)
    let state = PaywallViewUpdate.claimed(claim, isHandedOut: false)
      .reduce(PaywallViewState(paywall: .stub()))
    #expect(state.currentClaim?.id == claim.id)
    #expect(state.request != nil)
    #expect(state.unsavedOccurrence == occurrence)
    guard case .none = state.handedOut else {
      Issue.record("Expected no handed out claim")
      return
    }
  }

  @Test("A claim for another version of the paywall replaces it, and one for the same version updates it")
  func claimPaywall() {
    var other = Paywall.stub()
    other.cacheKey = "other"
    let start = PaywallViewState(paywall: .stub())
    let replaced = PaywallViewUpdate.claimed(makeClaim(paywall: other), isHandedOut: false).reduce(start)
    #expect(replaced.paywall.cacheKey == "other")

    var sameVersion = Paywall.stub()
    sameVersion.presentationSourceType = "register"
    let updated = PaywallViewUpdate.claimed(makeClaim(paywall: sameVersion), isHandedOut: false)
      .reduce(start)
    #expect(updated.paywall.cacheKey == start.paywall.cacheKey)
    #expect(updated.paywall.presentationSourceType == "register")
  }

  @Test("A claim made after the SDK asked to show the paywall starts over")
  func claimAfterRequest() {
    let requested = PaywallViewUpdate.sdkPresentationRequested.reduce(PaywallViewState(paywall: .stub()))
    #expect(requested.isPresentedBySDK)
    let claimed = PaywallViewUpdate.claimed(makeClaim(), isHandedOut: false).reduce(requested)
    #expect(!claimed.isPresentedBySDK)
  }

  @Test("A handed out claim is current until another claim replaces it, then waits to be restored")
  func handedOutClaim() {
    let handedOut = makeClaim(occurrence: .stub())
    var state = PaywallViewUpdate.claimed(handedOut, isHandedOut: true)
      .reduce(PaywallViewState(paywall: .stub()))
    guard case .current = state.handedOut else {
      Issue.record("Expected the handed out claim to be current")
      return
    }

    // Saving the occurrence clears it on the handed out claim too, as it's the same claim.
    state = PaywallViewUpdate.occurrenceSaved.reduce(state)
    #expect(state.unsavedOccurrence == nil)

    let other = makeClaim()
    state = PaywallViewUpdate.claimed(other, isHandedOut: false).reduce(state)
    #expect(state.currentClaim?.id == other.id)
    guard case .awaitingRestore(let waiting) = state.handedOut else {
      Issue.record("Expected the handed out claim to wait")
      return
    }
    #expect(waiting.id == handedOut.id)
    #expect(waiting.unsavedOccurrence == nil)

    // Another claim leaves it waiting.
    state = PaywallViewUpdate.claimed(makeClaim(), isHandedOut: false).reduce(state)
    guard case .awaitingRestore(let stillWaiting) = state.handedOut else {
      Issue.record("Expected the handed out claim to keep waiting")
      return
    }
    #expect(stillWaiting.id == handedOut.id)

    state = PaywallViewUpdate.handedOutClaimRestored.reduce(state)
    #expect(state.currentClaim?.id == handedOut.id)
    guard case .current = state.handedOut else {
      Issue.record("Expected the restored claim to be current")
      return
    }
  }

  @Test("A claim deferred while on screen waits, and restoring with none waiting does nothing")
  func deferredClaim() {
    let deferred = makeClaim()
    let state = PaywallViewUpdate.handedOutClaimDeferred(deferred)
      .reduce(PaywallViewState(paywall: .stub()))
    guard case .awaitingRestore(let waiting) = state.handedOut else {
      Issue.record("Expected the claim to wait")
      return
    }
    #expect(waiting.id == deferred.id)
    #expect(state.currentClaim == nil)

    let nothingWaiting = PaywallViewUpdate.handedOutClaimRestored.reduce(PaywallViewState(paywall: .stub()))
    #expect(nothingWaiting.currentClaim == nil)
  }
}

@Suite("PaywallViewUpdate presentation")
struct PaywallViewPresentationTests {
  @Test("A presentation goes from requested, to appearing, to presented, to dismissing, to idle")
  func phases() {
    let claim = makeClaim()
    var state = PaywallViewState(paywall: .stub())
    #expect(state.startsPresentationOnAppear)
    #expect(!state.isPresented)

    state = PaywallViewUpdate.sdkPresentationRequested.reduce(state)
    #expect(state.isPresentedBySDK)
    #expect(state.startsPresentationOnAppear)

    let presentation = PaywallViewState.Presentation(isPresentedBySDK: true, claimId: claim.id)
    state = PaywallViewUpdate.presentationWillBegin(presentation).reduce(state)
    #expect(!state.startsPresentationOnAppear)
    #expect(!state.isPresented)
    #expect(state.isPresentedBySDK)

    state = PaywallViewUpdate.presentationDidFinish.reduce(state)
    #expect(state.isPresented)
    #expect(state.activePresentation?.id == presentation.id)

    // Already on screen, so the SDK can't ask to show it.
    #expect(PaywallViewUpdate.sdkPresentationRequested.reduce(state).activePresentation != nil)

    state = PaywallViewUpdate.disappeared.reduce(state)
    #expect(state.isPresented)
    #expect(state.activePresentation == nil)
    #expect(state.startsPresentationOnAppear)
    #expect(!state.isPresentedBySDK)

    // A stale id doesn't finish it.
    state = PaywallViewUpdate.dismissalFinished(UUID()).reduce(state)
    #expect(state.isPresented)
    state = PaywallViewUpdate.dismissalFinished(presentation.id).reduce(state)
    #expect(!state.isPresented)
    guard case .idle = state.phase else {
      Issue.record("Expected idle")
      return
    }
  }

  @Test("Finishing appearing only moves an appearing presentation on, and disappearing only a presented one")
  func outOfOrderEvents() {
    let idle = PaywallViewState(paywall: .stub())
    #expect(!PaywallViewUpdate.presentationDidFinish.reduce(idle).isPresented)
    let appearing = PaywallViewUpdate.presentationWillBegin(.init(isPresentedBySDK: false, claimId: nil))
      .reduce(idle)
    guard case .appearing = PaywallViewUpdate.disappeared.reduce(appearing).phase else {
      Issue.record("Expected appearing")
      return
    }
  }

  @Test("A presentation beginning clears the close reason and the last presentation's purchase")
  func presentationWillBegin() {
    var state = PaywallViewState(paywall: .stub())
    state.paywall.closeReason = .manualClose
    state = PaywallViewUpdate.purchaseCompleted(.blank()).reduce(state)
    #expect(state.completedPurchase != nil)
    state = PaywallViewUpdate.presentationWillBegin(.init(isPresentedBySDK: false, claimId: nil))
      .reduce(state)
    #expect(state.paywall.closeReason == .none)
    #expect(state.completedPurchase == nil)
  }

  @Test("A dismissal request records the result and close reason, even once the paywall has gone")
  func dismissRequested() {
    let dismissal = PaywallViewState.Dismissal(result: .declined, closeReason: .manualClose)
    let presented = PaywallViewUpdate.dismissRequested(dismissal).reduce(presentedState())
    #expect(presented.activePresentation?.dismissal == dismissal)
    #expect(presented.paywall.closeReason == .manualClose)

    // A sheet swiped away asks to be dismissed after it has gone.
    let dismissing = reduce(presentedState(), .disappeared, .dismissRequested(dismissal), .delegateCalled)
    #expect(dismissing.latestPresentation?.dismissal == dismissal)
    #expect(dismissing.latestPresentation?.didCallDelegate == true)

    // With nothing on screen only the close reason is kept.
    let idle = PaywallViewUpdate.dismissRequested(dismissal).reduce(PaywallViewState(paywall: .stub()))
    #expect(idle.latestPresentation == nil)
    #expect(idle.paywall.closeReason == .manualClose)
  }

  @Test("A decline after a purchase resolves to the purchase, unless it's for the next paywall")
  func resolvedDismissal() {
    let state = PaywallViewUpdate.purchaseCompleted(.blank(productIdentifier: "product"))
      .reduce(PaywallViewState(paywall: .stub()))
    let declined = state.resolvedDismissal(result: .declined, closeReason: .manualClose)
    #expect(declined.result == .purchased(.blank(productIdentifier: "product")))
    #expect(declined.closeReason == .systemLogic)
    let restored = state.resolvedDismissal(result: .restored, closeReason: .systemLogic)
    #expect(restored.result == .restored)
    let forNext = state.resolvedDismissal(result: .declined, closeReason: .forNextPaywall)
    #expect(forNext == .init(result: .declined, closeReason: .forNextPaywall))
  }

  @Test("A presentation that begins while the last one's dismissal finishes leaves that one to finish by itself")
  func presentationBeginsWhileDismissing() {
    var state = reduce(presentedState(), .disappeared)
    let first = try! #require(state.latestPresentation)
    let second = PaywallViewState.Presentation(isPresentedBySDK: false, claimId: first.claimId)
    state = reduce(state, .presentationWillBegin(second), .presentationDidFinish)
    #expect(state.activePresentation?.id == second.id)
    #expect(state.supersededDismissals.map(\.id) == [first.id])
    #expect(state.finishingDismissal(first.id)?.id == first.id)

    state = PaywallViewUpdate.dismissalFinished(first.id).reduce(state)
    #expect(state.supersededDismissals.isEmpty)
    #expect(state.isPresented)
    #expect(state.activePresentation?.id == second.id)
  }

  @Test("The SDK asking to show the paywall while its dismissal finishes leaves that one to finish by itself")
  func requestedWhileDismissing() {
    var state = reduce(presentedState(), .disappeared)
    let first = try! #require(state.latestPresentation)
    state = PaywallViewUpdate.sdkPresentationRequested.reduce(state)
    #expect(state.isPresentedBySDK)
    #expect(state.finishingDismissal(first.id)?.id == first.id)
  }

  @Test("A survey's result, a blocked swipe, the open time and the popup's tap are recorded")
  func presentationRecords() {
    let opened = Date(timeIntervalSince1970: 1)
    var state = reduce(
      presentedState(),
      .surveyFinished(.show),
      .surveySwipeBlocked,
      .opened(opened),
      .popupBackgroundTapped
    )
    #expect(state.surveyPresentationResult == .show)
    #expect(state.activePresentation?.isSwipeDisabledForSurvey == true)
    #expect(state.lastOpen == opened)
    #expect(state.isPopupBackgroundDismissing)

    state = reduce(state, .closed, .popupBackgroundAnimationEnded)
    #expect(state.lastOpen == nil)
    #expect(!state.isPopupBackgroundDismissing)
  }
}

@Suite("PaywallViewUpdate browser and checkout")
struct PaywallViewBrowserTests {
  @Test("Safari opens and closes")
  func safari() {
    var state = PaywallViewUpdate.safariOpened.reduce(PaywallViewState(paywall: .stub()))
    #expect(state.isBrowserOpen)
    state = PaywallViewUpdate.safariClosed.reduce(state)
    #expect(!state.isBrowserOpen)

    // The SDK closing Safari closes it straight away, as Safari doesn't report it.
    state = reduce(state, .safariOpened, .browserClosedBySDK)
    #expect(state.browser == .none)
  }

  @Test("Nothing opens while a browser is open or closing, so the one showing keeps its state")
  func openWhileOpen() {
    let id = UUID()
    let open = PaywallViewUpdate.checkoutOpened(id).reduce(PaywallViewState(paywall: .stub()))
    #expect(reduce(open, .checkoutOpened(UUID())).browser == open.browser)
    #expect(reduce(open, .safariOpened).browser == open.browser)

    let closing = PaywallViewUpdate.browserClosedBySDK.reduce(open)
    #expect(reduce(closing, .checkoutOpened(UUID())).browser == closing.browser)

    let safari = PaywallViewUpdate.safariOpened.reduce(PaywallViewState(paywall: .stub()))
    #expect(reduce(safari, .checkoutOpened(UUID())).browser == .safari)
  }

  @Test("Closing the checkout sheet with nothing settled is an abandon, and makes the paywall ready")
  func checkoutClosedByBuyer() {
    let id = UUID()
    var state = PaywallViewUpdate.checkoutOpened(id).reduce(PaywallViewState(paywall: .stub()))
    state.loadingState = .loadingPurchase
    #expect(state.isBrowserOpen)
    let sheet = try! #require(state.checkoutSheet(id))
    #expect(state.isAbandon(closing: sheet))

    // Another sheet's close does nothing.
    #expect(PaywallViewUpdate.checkoutClosed(UUID()).reduce(state).isBrowserOpen)

    state = PaywallViewUpdate.checkoutClosed(id).reduce(state)
    #expect(state.browser == .none)
    #expect(state.loadingState == .ready)
    #expect(state.loadingStateWrites == 1)
  }

  @Test("The SDK closing the checkout sheet settles it and keeps the spinner when it goes")
  func checkoutClosedBySDK() {
    let id = UUID()
    var state = PaywallViewUpdate.checkoutOpened(id).reduce(PaywallViewState(paywall: .stub()))
    state.loadingState = .manualLoading
    state = PaywallViewUpdate.browserClosedBySDK.reduce(state)
    #expect(!state.isBrowserOpen)
    #expect(state.checkoutSheet(id)?.settled == .closedBySDK)

    state = PaywallViewUpdate.checkoutClosed(id).reduce(state)
    #expect(state.browser == .none)
    #expect(state.loadingState == .manualLoading)
    #expect(state.loadingStateWrites == 0)
  }

  @Test("Each settling event settles the open sheet, and the first one is kept")
  func settled() {
    let cases: [(PaywallViewUpdate, PaywallViewState.CheckoutSheet.Settled)] = [
      (.redeemSucceeded, .redeemed),
      (.stripeCheckoutAbandoned, .pageReportedOutcome),
      (.stripeCheckoutCompleted, .pageReportedOutcome),
      (.customStoreCheckoutAdvanced(productId: "product", closesBrowser: false), .customStoreCheckoutEnded)
    ]
    for (update, settled) in cases {
      let id = UUID()
      var state = reduce(PaywallViewState(paywall: .stub()), .checkoutOpened(id), update)
      #expect(state.checkoutSheet(id)?.settled == settled)
      #expect(!state.isAbandon(closing: state.checkoutSheet(id)!))

      state = PaywallViewUpdate.redeemSucceeded.reduce(state)
      #expect(state.checkoutSheet(id)?.settled == settled)
      // The SDK closing it always wins, as it decides the loading state.
      state = PaywallViewUpdate.browserClosedBySDK.reduce(state)
      #expect(state.checkoutSheet(id)?.settled == .closedBySDK)
    }
  }

  @Test("Settling events with no checkout sheet open change nothing in the browser")
  func settledWithoutSheet() {
    let state = reduce(
      PaywallViewState(paywall: .stub()),
      .safariOpened,
      .redeemSucceeded,
      .stripeCheckoutAbandoned
    )
    #expect(state.browser == .safari)
  }

  @Test("A completed Stripe checkout shows the spinner")
  func stripeCheckoutCompleted() {
    var state = PaywallViewState(paywall: .stub())
    state.loadingState = .ready
    state = PaywallViewUpdate.stripeCheckoutCompleted.reduce(state)
    #expect(state.loadingState == .manualLoading)
    #expect(state.loadingStateWrites == 1)
  }

  @Test("A custom store checkout keeps its product until it finishes, and closing its sheet isn't an abandon")
  func customStoreCheckout() {
    let id = UUID()
    var state = reduce(
      PaywallViewState(paywall: .stub()),
      .checkoutOpened(id),
      .customStoreCheckoutAdvanced(productId: "product", closesBrowser: true)
    )
    #expect(state.customStoreCheckoutProductId == "product")
    #expect(state.checkoutSheet(id)?.settled == nil)
    #expect(!state.isAbandon(closing: state.checkoutSheet(id)!))

    state = PaywallViewUpdate.customStoreCheckoutFinished.reduce(state)
    #expect(state.customStoreCheckoutProductId == nil)
    #expect(state.isAbandon(closing: state.checkoutSheet(id)!))
  }
}

// MARK: - Actions

/// Records every side effect an action asks for.
private final class FakePaywallViewContext: PaywallViewContext {
  enum Call: Equatable {
    case publishLoadingState(PaywallLoadingState, from: PaywallLoadingState)
    case sendState(PaywallViewStateEvent, claim: UUID)
    case finishStatePublisher(claim: UUID)
    case runDismissCompletion(UUID)
    case storePresentationObjects(claim: UUID?)
    case installDelegate
    case callDidFinish(PaywallResult, shouldDismiss: Bool)
    case callDidFinishToPresentationDelegate(PaywallResult)
    case notifyWillPresent
    case notifyDidPresent
    case notifyWillDismiss
    case notifyDidDismiss
    case reloadWebView
    case sendTemplateParams
    case fetchIntroOfferTokens
    case saveOccurrence
    case trackOpen
    case trackClose
    case markActive(Bool)
    case destroyPresentingWindow
    case listenToGameController(Bool)
    case restoreSwipeAfterSurvey
    case scheduleCheckoutAbandonTracking
    case cancelCheckoutAbandonTracking
    case notifyCustomStoreCheckoutEnded
  }

  let store: PaywallViewStore
  var delegate: PaywallViewControllerDelegateAdapter? = PaywallViewControllerDelegateAdapter(
    swiftDelegate: nil,
    objcDelegate: nil
  )
  var calls: [Call] = []
  var publishers: [UUID: PassthroughSubject<PaywallState, Never>] = [:]
  var completions: [UUID: () -> Void] = [:]
  var reopened: [UUID] = []

  init(state: PaywallViewState = PaywallViewState(paywall: .stub())) {
    store = PaywallViewStore(initial: state)
    publishLoadingStateWrites()
  }

  func publishLoadingState(_ loadingState: PaywallLoadingState, from oldValue: PaywallLoadingState) {
    calls.append(.publishLoadingState(loadingState, from: oldValue))
  }
  func registerStatePublisher(_ publisher: PassthroughSubject<PaywallState, Never>, forClaim id: UUID) {
    publishers[id] = publisher
  }
  func reopenStatePublisherIfFinished(forClaim id: UUID) {
    reopened.append(id)
  }
  func keepStatePublishers(forClaims ids: Set<UUID>) {
    publishers = publishers.filter { ids.contains($0.key) }
  }
  func saveDismissCompletion(_ completion: @escaping () -> Void, forPresentation id: UUID) {
    completions[id] = completion
  }
  func sendState(_ event: PaywallViewStateEvent, toClaim id: UUID) { calls.append(.sendState(event, claim: id)) }
  func finishStatePublisher(forClaim id: UUID) { calls.append(.finishStatePublisher(claim: id)) }
  func runDismissCompletion(forPresentation id: UUID) { calls.append(.runDismissCompletion(id)) }
  func storePresentationObjects(forClaim id: UUID?) { calls.append(.storePresentationObjects(claim: id)) }
  func installDelegate(for request: PresentationRequest) { calls.append(.installDelegate) }
  func callDidFinish(_ result: PaywallResult, shouldDismiss: Bool) {
    calls.append(.callDidFinish(result, shouldDismiss: shouldDismiss))
  }
  func callDidFinish(_ result: PaywallResult, to delegate: PaywallViewControllerDelegateAdapter?) {
    calls.append(.callDidFinishToPresentationDelegate(result))
  }
  func notifyWillPresent() { calls.append(.notifyWillPresent) }
  func notifyDidPresent() { calls.append(.notifyDidPresent) }
  func notifyWillDismiss() { calls.append(.notifyWillDismiss) }
  func notifyDidDismiss() { calls.append(.notifyDidDismiss) }
  func reloadWebView() { calls.append(.reloadWebView) }
  func sendTemplateParams() { calls.append(.sendTemplateParams) }
  func fetchIntroOfferTokens() { calls.append(.fetchIntroOfferTokens) }
  func saveOccurrence(_ occurrence: TriggerAudienceOccurrence) { calls.append(.saveOccurrence) }
  func trackOpen() { calls.append(.trackOpen) }
  func trackClose() { calls.append(.trackClose) }
  func markActive(_ isActive: Bool) { calls.append(.markActive(isActive)) }
  func destroyPresentingWindow() { calls.append(.destroyPresentingWindow) }
  func listenToGameController(_ isListening: Bool) { calls.append(.listenToGameController(isListening)) }
  func restoreSwipeAfterSurvey() { calls.append(.restoreSwipeAfterSurvey) }
  func scheduleCheckoutAbandonTracking() { calls.append(.scheduleCheckoutAbandonTracking) }
  func cancelCheckoutAbandonTracking() { calls.append(.cancelCheckoutAbandonTracking) }
  func notifyCustomStoreCheckoutEnded() { calls.append(.notifyCustomStoreCheckoutEnded) }

  /// Claims and shows the paywall, then forgets the calls that made.
  func present(_ claim: PaywallViewState.Claim = makeClaim()) {
    dispatch(.claim(claim, publisher: PassthroughSubject(), isHandedOut: false, isActive: false))
    dispatch(.event(.sdkPresentationRequested))
    dispatch(.beginPresentation)
    dispatch(.finishAppearing)
    calls = []
  }
}

@Suite("PaywallViewAction")
struct PaywallViewActionTests {
  @Test("An event publishes every loading state write, even an unchanged one, and nothing else")
  func eventPublishesLoadingWrites() {
    let context = FakePaywallViewContext()
    context.dispatch(.event(.loading(.finished)))
    context.dispatch(.event(.loading(.finished)))
    context.dispatch(.event(.loading(.manualLoadingEnded)))
    context.dispatch(.event(.safariOpened))
    #expect(context.calls == [
      .publishLoadingState(.ready, from: .unknown),
      .publishLoadingState(.ready, from: .ready)
    ])
    #expect(context.dispatch(.event(.loading(.spinnerRequested))) == .loadingState(.manualLoading))
  }

  @Test("A claim installs its delegate, and reloads only for another version of the paywall")
  func claim() {
    let context = FakePaywallViewContext()
    let publisher = PassthroughSubject<PaywallState, Never>()
    let sameVersion = makeClaim()
    let outcome = context.dispatch(
      .claim(sameVersion, publisher: publisher, isHandedOut: false, isActive: false)
    )
    #expect(outcome == .loadStarted(false))
    #expect(context.calls == [.installDelegate])
    #expect(context.publishers[sameVersion.id] === publisher)

    context.calls = []
    var other = Paywall.stub()
    other.cacheKey = "other"
    let newVersion = makeClaim(paywall: other)
    #expect(context.dispatch(.claim(newVersion, publisher: .init(), isHandedOut: false, isActive: false)) == .loadStarted(true))
    #expect(context.calls == [.installDelegate, .reloadWebView])
    // The replaced claim's publisher is let go of.
    #expect(context.publishers[sameVersion.id] == nil)
  }

  @Test("A claim made while on screen only waits, if it's handed out")
  func claimWhileActive() {
    let context = FakePaywallViewContext()
    context.present()
    let handedOut = makeClaim()
    context.dispatch(.claim(handedOut, publisher: .init(), isHandedOut: true, isActive: true))
    context.dispatch(.claim(makeClaim(), publisher: .init(), isHandedOut: false, isActive: true))
    #expect(context.calls.isEmpty)
    guard case .awaitingRestore(let waiting) = context.state.handedOut else {
      Issue.record("Expected the claim to wait")
      return
    }
    #expect(waiting.id == handedOut.id)
    #expect(context.publishers[handedOut.id] != nil)
  }

  @Test("The app showing a handed out view controller restores its claim, once, if the SDK isn't showing it")
  func restoreHandedOutClaim() {
    let handedOut = makeClaim()
    func makeContext() -> FakePaywallViewContext {
      let context = FakePaywallViewContext()
      context.dispatch(.claim(handedOut, publisher: .init(), isHandedOut: true, isActive: false))
      context.dispatch(.claim(makeClaim(), publisher: .init(), isHandedOut: false, isActive: false))
      return context
    }

    // The SDK showing it keeps its own claim.
    let shownBySDK = makeContext()
    shownBySDK.dispatch(.event(.sdkPresentationRequested))
    #expect(shownBySDK.dispatch(.restoreHandedOutClaim) == .loadStarted(false))
    #expect(shownBySDK.state.currentClaim?.id != handedOut.id)

    let context = makeContext()
    context.calls = []
    #expect(context.dispatch(.restoreHandedOutClaim) == .loadStarted(false))
    #expect(context.state.currentClaim?.id == handedOut.id)
    #expect(context.reopened == [handedOut.id])
    #expect(context.calls == [.installDelegate])

    context.calls = []
    context.dispatch(.restoreHandedOutClaim)
    #expect(context.calls.isEmpty)
  }

  @Test("Beginning a presentation runs once, and sends the templates only when the page is ready")
  func beginPresentation() {
    let context = FakePaywallViewContext()
    context.dispatch(.event(.loading(.finished)))
    context.calls = []
    #expect(context.dispatch(.beginPresentation) == .presentationBegan(true))
    #expect(context.calls == [
      .fetchIntroOfferTokens,
      .notifyCustomStoreCheckoutEnded,
      .notifyWillPresent,
      .sendTemplateParams
    ])
    context.calls = []
    #expect(context.dispatch(.beginPresentation) == .presentationBegan(false))
    #expect(context.calls.isEmpty)
  }

  @Test("Appearing saves the occurrence once, and reports the presentation")
  func finishAppearing() {
    let context = FakePaywallViewContext()
    let claim = makeClaim(occurrence: .stub())
    context.dispatch(.claim(claim, publisher: .init(), isHandedOut: false, isActive: false))
    context.dispatch(.beginPresentation)
    context.calls = []
    context.dispatch(.finishAppearing)
    #expect(context.calls == [
      .storePresentationObjects(claim: claim.id),
      .saveOccurrence,
      .notifyDidPresent,
      .trackOpen,
      .listenToGameController(true)
    ])
    #expect(context.state.unsavedOccurrence == nil)
    #expect(context.state.isPresented)

    context.calls = []
    context.dispatch(.finishAppearing)
    #expect(context.calls.isEmpty)
  }

  @Test("A dismissal request returns what it resolved to, and keeps the completion for its presentation")
  func requestDismissal() {
    let context = FakePaywallViewContext()
    context.present()
    context.dispatch(.event(.purchaseCompleted(.blank())))
    let outcome = context.dispatch(
      .requestDismissal(result: .declined, closeReason: .manualClose, completion: {})
    )
    #expect(outcome == .dismissal(.init(result: .purchased(.blank()), closeReason: .systemLogic)))
    let id = try! #require(context.state.activePresentation?.id)
    #expect(context.completions[id] != nil)
  }

  @Test("Reporting the finish tells the delegate if there is one")
  func reportFinished() {
    let context = FakePaywallViewContext()
    context.present()
    let dismissal = PaywallViewState.Dismissal(result: .declined, closeReason: .manualClose)
    context.delegate = nil
    #expect(context.dispatch(.reportFinished(dismissal)) == .finishReported(toDelegate: false))
    #expect(context.calls.isEmpty)

    context.delegate = PaywallViewControllerDelegateAdapter(swiftDelegate: nil, objcDelegate: nil)
    #expect(context.dispatch(.reportFinished(dismissal)) == .finishReported(toDelegate: true))
    #expect(context.calls == [.callDidFinish(.declined, shouldDismiss: true)])
    #expect(context.state.activePresentation?.didCallDelegate == true)
  }

  @Test("Disappearing reports the dismissal and starts finishing it, unless the browser is open")
  func disappear() {
    let context = FakePaywallViewContext()
    let claim = makeClaim()
    context.present(claim)
    context.dispatch(.event(.safariOpened))
    context.dispatch(.willDisappear)
    #expect(context.dispatch(.didDisappear) == .dismissalStarted(nil))
    #expect(context.calls.isEmpty)

    context.dispatch(.event(.safariClosed))
    let id = try! #require(context.state.activePresentation?.id)
    context.dispatch(.requestDismissal(result: .restored, closeReason: .systemLogic, completion: nil))
    context.dispatch(.willDisappear)
    #expect(context.dispatch(.didDisappear) == .dismissalStarted(id))
    #expect(context.calls == [
      .sendState(.willDismiss(.restored), claim: claim.id),
      .notifyWillDismiss,
      .trackClose
    ])
  }

  @Test("Finishing the dismissal resets the paywall and reports the end of its presentation")
  func finishDismissal() {
    let context = FakePaywallViewContext()
    let claim = makeClaim()
    context.present(claim)
    context.dispatch(.event(.surveySwipeBlocked))
    let id = try! #require(context.state.activePresentation?.id)
    context.dispatch(.didDisappear)
    context.calls = []

    context.dispatch(.finishDismissal(id))
    #expect(context.calls == [
      .destroyPresentingWindow,
      .listenToGameController(false),
      .restoreSwipeAfterSurvey,
      .notifyCustomStoreCheckoutEnded,
      .markActive(false),
      .runDismissCompletion(id),
      .sendState(.dismissed(.declined), claim: claim.id),
      .callDidFinish(.declined, shouldDismiss: false),
      .finishStatePublisher(claim: claim.id),
      .notifyDidDismiss
    ])
    #expect(!context.state.isPresented)

    // Finishing it again does nothing.
    context.calls = []
    context.dispatch(.finishDismissal(id))
    #expect(context.calls.isEmpty)
  }

  @Test("A dismissal for the next paywall leaves its publisher open, and a delegate told already isn't told again")
  func finishDismissalForNextPaywall() {
    let context = FakePaywallViewContext()
    let claim = makeClaim()
    context.present(claim)
    let id = try! #require(context.state.activePresentation?.id)
    context.dispatch(.requestDismissal(result: .declined, closeReason: .forNextPaywall, completion: nil))
    context.dispatch(.reportFinished(.init(result: .declined, closeReason: .forNextPaywall)))
    context.dispatch(.didDisappear)
    context.calls = []
    context.dispatch(.finishDismissal(id))
    #expect(!context.calls.contains(.finishStatePublisher(claim: claim.id)))
    #expect(!context.calls.contains { if case .callDidFinish = $0 { return true }; return false })
  }

  @Test("A dismissal finishing after the paywall was shown again reports for its own presentation only")
  func finishSupersededDismissal() {
    let context = FakePaywallViewContext()
    let claim = makeClaim()
    context.present(claim)
    let first = try! #require(context.state.activePresentation?.id)
    context.dispatch(.reportFinished(.init(result: .declined, closeReason: .manualClose)))
    context.dispatch(.didDisappear)

    // Shown again before the first dismissal finished.
    context.dispatch(.beginPresentation)
    context.dispatch(.finishAppearing)
    let second = try! #require(context.state.activePresentation?.id)
    context.calls = []

    context.dispatch(.finishDismissal(first))
    #expect(context.calls == [
      .runDismissCompletion(first),
      .sendState(.dismissed(.declined), claim: claim.id),
      .notifyDidDismiss
    ])
    // The second presentation is untouched, and its publisher stays open.
    #expect(context.state.isPresented)
    #expect(context.state.activePresentation?.id == second)
    #expect(!context.state.activePresentation!.didCallDelegate)
    #expect(context.publishers[claim.id] != nil)
  }

  @Test("A dismissal finishing while the next presentation is dismissing leaves their publisher open")
  func finishSupersededDismissalWhileNextIsDismissing() {
    let context = FakePaywallViewContext()
    let claim = makeClaim()
    context.present(claim)
    let first = try! #require(context.state.activePresentation?.id)
    context.dispatch(.reportFinished(.init(result: .declined, closeReason: .manualClose)))
    context.dispatch(.didDisappear)

    // Shown again and closed before the first dismissal finished.
    context.dispatch(.beginPresentation)
    context.dispatch(.finishAppearing)
    let second = try! #require(context.state.activePresentation?.id)
    context.dispatch(.reportFinished(.init(result: .declined, closeReason: .manualClose)))
    context.dispatch(.didDisappear)
    context.calls = []

    context.dispatch(.finishDismissal(first))
    #expect(!context.calls.contains(.finishStatePublisher(claim: claim.id)))
    #expect(context.publishers[claim.id] != nil)

    // The second one still reports its end, then finishes the publisher.
    context.calls = []
    context.dispatch(.finishDismissal(second))
    #expect(context.calls.contains(.sendState(.dismissed(.declined), claim: claim.id)))
    #expect(context.calls.contains(.finishStatePublisher(claim: claim.id)))
  }

  @Test("A dismissal finishing after the paywall was shown again undoes its survey's swipe block")
  func finishSupersededDismissalRestoresSwipe() {
    let context = FakePaywallViewContext()
    let claim = makeClaim()
    context.present(claim)
    context.dispatch(.event(.surveySwipeBlocked))
    let first = try! #require(context.state.activePresentation?.id)
    context.dispatch(.reportFinished(.init(result: .declined, closeReason: .manualClose)))
    context.dispatch(.didDisappear)

    // Shown again before the first dismissal finished.
    context.dispatch(.beginPresentation)
    context.dispatch(.finishAppearing)
    context.calls = []

    context.dispatch(.finishDismissal(first))
    #expect(context.calls.contains(.restoreSwipeAfterSurvey))
    #expect(!context.calls.contains(.destroyPresentingWindow))
  }

  @Test("A superseded dismissal leaves the swipe blocked if the new presentation blocked it for its own survey")
  func finishSupersededDismissalKeepsNewSwipeBlock() {
    let context = FakePaywallViewContext()
    let claim = makeClaim()
    context.present(claim)
    context.dispatch(.event(.surveySwipeBlocked))
    let first = try! #require(context.state.activePresentation?.id)
    context.dispatch(.reportFinished(.init(result: .declined, closeReason: .manualClose)))
    context.dispatch(.didDisappear)

    context.dispatch(.beginPresentation)
    context.dispatch(.finishAppearing)
    context.dispatch(.event(.surveySwipeBlocked))
    context.calls = []

    context.dispatch(.finishDismissal(first))
    #expect(!context.calls.contains(.restoreSwipeAfterSurvey))
  }

  @Test("A loading state written by a direct store update is published too")
  func directUpdatePublishesLoadingState() {
    let context = FakePaywallViewContext()
    context.store.update(PaywallViewUpdate.loading(.finished))
    #expect(context.calls == [.publishLoadingState(.ready, from: .unknown)])
  }

  @Test("A second checkout sheet doesn't open over the first, whose close still makes the paywall ready")
  func secondCheckoutDoesNotOpen() {
    let context = FakePaywallViewContext()
    let first = UUID()
    #expect(context.dispatch(.openCheckout(first)) == .browserOpened(true))
    context.dispatch(.event(.loading(.purchaseStarted)))
    context.calls = []

    // A double tap asks for a second sheet.
    #expect(context.dispatch(.openCheckout(UUID())) == .browserOpened(false))
    #expect(context.dispatch(.openSafari) == .browserOpened(false))
    #expect(context.calls.isEmpty)

    #expect(context.dispatch(.closeCheckout(first)) == .checkoutClosed(wasAbandon: true))
    #expect(context.state.browser == .none)
    #expect(context.state.loadingState == .ready)
    #expect(context.dispatch(.openSafari) == .browserOpened(true))
  }

  @Test("A dismissal finishing after the paywall was shown again tells the delegate it began with")
  func finishSupersededDismissalTellsItsOwnDelegate() {
    let context = FakePaywallViewContext()
    // The SDK's presentation has no delegate, so it isn't told on close.
    context.delegate = nil
    let claim = makeClaim()
    context.present(claim)
    let first = try! #require(context.state.activePresentation?.id)
    context.dispatch(.requestDismissal(result: .declined, closeReason: .manualClose, completion: nil))
    #expect(context.dispatch(.reportFinished(.init(result: .declined, closeReason: .manualClose))) == .finishReported(toDelegate: false))
    context.dispatch(.didDisappear)

    // Shown again, by the app, with its own delegate.
    context.delegate = PaywallViewControllerDelegateAdapter(swiftDelegate: nil, objcDelegate: nil)
    context.dispatch(.beginPresentation)
    context.dispatch(.finishAppearing)
    let second = try! #require(context.state.activePresentation?.id)
    context.calls = []

    context.dispatch(.finishDismissal(first))
    #expect(context.calls.contains(.callDidFinishToPresentationDelegate(.declined)))
    #expect(!context.calls.contains(.callDidFinish(.declined, shouldDismiss: false)))

    // The latest presentation's end goes to the current delegate, as before.
    context.dispatch(.requestDismissal(result: .declined, closeReason: .manualClose, completion: nil))
    context.dispatch(.didDisappear)
    context.calls = []
    context.dispatch(.finishDismissal(second))
    #expect(context.calls.contains(.callDidFinish(.declined, shouldDismiss: false)))
  }

  @Test("Closing the checkout sheet tracks an abandon only when nothing settled it")
  func closeCheckout() {
    let context = FakePaywallViewContext()
    let id = UUID()
    context.dispatch(.openCheckout(id))
    #expect(context.calls == [.cancelCheckoutAbandonTracking])
    context.calls = []
    #expect(context.dispatch(.closeCheckout(id)) == .checkoutClosed(wasAbandon: true))
    #expect(context.calls == [.publishLoadingState(.ready, from: .unknown), .scheduleCheckoutAbandonTracking])

    let settledId = UUID()
    context.dispatch(.openCheckout(settledId))
    context.dispatch(.redeemSucceeded)
    context.calls = []
    #expect(context.dispatch(.closeCheckout(settledId)) == .checkoutClosed(wasAbandon: false))
    #expect(!context.calls.contains(.scheduleCheckoutAbandonTracking))

    // An unknown sheet's close does nothing.
    context.calls = []
    #expect(context.dispatch(.closeCheckout(UUID())) == .checkoutClosed(wasAbandon: false))
    #expect(context.calls.isEmpty)
  }

  @Test("A redeem or the page's abandon cancels the abandon tracking")
  func cancelAbandonTracking() {
    let context = FakePaywallViewContext()
    context.dispatch(.redeemSucceeded)
    context.dispatch(.stripeCheckoutAbandoned)
    #expect(context.calls == [.cancelCheckoutAbandonTracking, .cancelCheckoutAbandonTracking])
  }

  @Test("Ending a custom store checkout clears it and tells the page")
  func endCustomStoreCheckout() {
    let context = FakePaywallViewContext()
    context.dispatch(.event(.customStoreCheckoutAdvanced(productId: "product", closesBrowser: true)))
    context.dispatch(.endCustomStoreCheckout)
    #expect(context.state.customStoreCheckoutProductId == nil)
    #expect(context.calls == [.notifyCustomStoreCheckoutEnded])
  }
}

// MARK: - View controller

@Suite("PaywallViewController store")
struct PaywallViewControllerStoreTests {
  /// The view controller holds its dependencies unowned and starts tasks that
  /// outlive the test, so anything it depends on lives for the whole process.
  private static var retained: [AnyObject] = []

  @MainActor
  private static func makeViewController() -> PaywallViewController {
    let container = DependencyContainer()
    retained.append(container)
    let webView = SWWebView(
      isiOSAppOnMac: false,
      messageHandler: PaywallMessageHandler(
        receiptManager: container.receiptManager,
        factory: container,
        permissionHandler: FakePermissionHandler(),
        customCallbackRegistry: container.customCallbackRegistry
      ),
      isOnDeviceCacheEnabled: true,
      factory: container
    )
    let viewController = PaywallViewController(
      paywall: .stub(),
      deviceHelper: container.deviceHelper,
      factory: container,
      storage: container.storage,
      network: container.network,
      webView: webView,
      webEntitlementRedeemer: container.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil,
      customCallbackRegistry: container.customCallbackRegistry
    )
    retained.append(viewController)
    // Loading the view starts loading the web view, which sets the loading
    // state, so it's done before a test watches the loading state.
    viewController.loadViewIfNeeded()
    return viewController
  }

  @Test("A loading state change is published before it returns on the main thread")
  @MainActor
  func publishesOnMain() {
    let viewController = Self.makeViewController()
    var published: [PaywallLoadingState] = []
    let cancellable = viewController.$loadingState
      .dropFirst()
      .sink { published.append($0) }
    defer { cancellable.cancel() }

    viewController.updateLoading(.finished)
    #expect(viewController.loadingState == .ready)
    viewController.togglePaywallSpinner(isHidden: false)
    #expect(viewController.loadingState == .manualLoading)
    viewController.togglePaywallSpinner(isHidden: true)
    viewController.togglePaywallSpinner(isHidden: true)
    viewController.updateLoading(.finished)

    // The repeated hide doesn't write, while finishing again is still published.
    #expect(published == [.ready, .manualLoading, .ready, .ready])
  }

  @Test("The page loading while a spinner shows for something else keeps the spinner")
  @MainActor
  func webContentLoadedKeepsManualSpinner() {
    let viewController = Self.makeViewController()
    viewController.updateLoading(.manualLoadingStarted)
    viewController.webContentDidLoad()
    #expect(viewController.loadingState == .manualLoading)
    viewController.updateLoading(.manualLoadingEnded)
    viewController.updateLoading(.webViewLoadStarted)
    viewController.webContentDidLoad()
    #expect(viewController.loadingState == .ready)
  }

  @Test("200 concurrent loading state changes are published on the main thread in order")
  func concurrentUpdatesPublishInOrder() async {
    let changes: [PaywallLoadingChange] = [.webViewLoadStarted, .finished, .manualLoadingStarted, .purchaseStarted]
    let viewController = await MainActor.run { Self.makeViewController() }
    let store = await MainActor.run { viewController.store }

    let lock = NSLock()
    var applied: [PaywallLoadingState] = []
    store.observe { before, after in
      guard after.loadingStateWrites != before.loadingStateWrites else {
        return
      }
      lock.lock()
      applied.append(after.loadingState)
      lock.unlock()
    }

    var published: [PaywallLoadingState] = []
    var publishedOffMain = false
    let cancellable = await MainActor.run {
      viewController.$loadingState
        .dropFirst()
        .sink { state in
          if !Thread.isMainThread {
            publishedOffMain = true
          }
          published.append(state)
        }
    }

    DispatchQueue.concurrentPerform(iterations: 200) { index in
      store.dispatch(PaywallViewAction.event(.loading(changes[index % changes.count])), in: viewController)
    }

    // Lets the main thread deliver every change.
    for _ in 0..<200 {
      let count = await MainActor.run { published.count }
      if count == 200 {
        break
      }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }

    await MainActor.run {
      lock.lock()
      #expect(published == applied)
      lock.unlock()
      #expect(published.count == 200)
      #expect(!publishedOffMain)
      #expect(viewController.loadingState == store.state.loadingState)
      cancellable.cancel()
    }
  }

  @Test("A subscriber that waits on another thread doesn't keep the store locked")
  func publishingDoesNotHoldTheStoreLock() async {
    let viewController = await MainActor.run { Self.makeViewController() }
    let store = await MainActor.run { viewController.store }
    let subscriberWaiting = DispatchSemaphore(value: 0)
    let gate = DispatchSemaphore(value: 0)
    let cancellable = await MainActor.run {
      viewController.$loadingState
        .dropFirst()
        .sink { _ in
          subscriberWaiting.signal()
          gate.wait()
        }
    }

    DispatchQueue.main.async {
      viewController.updateLoading(.finished)
    }
    #expect(subscriberWaiting.wait(timeout: .now() + 2) == .success)

    // The main thread is waiting in the subscriber. If it still held the
    // store's lock, this read would never return.
    let read = DispatchSemaphore(value: 0)
    var loadingState: PaywallLoadingState?
    Thread {
      loadingState = store.state.loadingState
      read.signal()
    }
    .start()
    let didRead = read.wait(timeout: .now() + 2) == .success
    gate.signal()

    #expect(didRead)
    #expect(loadingState == .ready)
    await MainActor.run { cancellable.cancel() }
  }
}
