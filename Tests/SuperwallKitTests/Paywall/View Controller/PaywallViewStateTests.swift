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

@Suite("PaywallViewUpdate reducers")
struct PaywallViewUpdateTests {
  private func request() -> PresentationRequest {
    let container = DependencyContainer()
    return container.makePresentationRequest(
      .implicitTrigger(PlacementData(name: "placement", parameters: [:], createdAt: Date())),
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .presentation
    )
  }

  private func claim(
    paywall: Paywall = .stub(),
    occurrence: TriggerAudienceOccurrence? = nil
  ) -> PaywallViewState.Claim {
    PaywallViewState.Claim(
      request: request(),
      paywall: paywall,
      paywallStatePublisher: PassthroughSubject(),
      unsavedOccurrence: occurrence
    )
  }

  @Test("Every loading state write counts as a publication, even an unchanged one")
  func loadingStatePublications() {
    let start = PaywallViewState(paywall: .stub())
    let once = PaywallViewUpdate.loadingState(.ready).reduce(start)
    let twice = PaywallViewUpdate.loadingState(.ready).reduce(once)
    #expect(twice.loadingState == .ready)
    #expect(twice.loadingStatePublications == 2)
  }

  @Test("Updates that don't write the loading state don't publish it")
  func otherUpdatesDontPublish() {
    let start = PaywallViewState(paywall: .stub())
    let updates: [PaywallViewUpdate] = [
      .safariPresented(true),
      .presented,
      .presentationWillBegin,
      .lastOpen(Date()),
      .hideSpinner,
      .showSpinner,
      .endManualLoading
    ]
    for update in updates {
      #expect(update.reduce(start).loadingStatePublications == 0)
    }
  }

  @Test("The spinner shows only once ready, and hides only while it's showing")
  func spinner() {
    var state = PaywallViewState(paywall: .stub())
    state.loadingState = .loadingURL
    #expect(PaywallViewUpdate.showSpinner.reduce(state).loadingState == .loadingURL)
    #expect(PaywallViewUpdate.hideSpinner.reduce(state).loadingState == .loadingURL)

    state.loadingState = .ready
    #expect(PaywallViewUpdate.showSpinner.reduce(state).loadingState == .manualLoading)

    state.loadingState = .loadingPurchase
    #expect(PaywallViewUpdate.hideSpinner.reduce(state).loadingState == .ready)
    #expect(PaywallViewUpdate.endManualLoading.reduce(state).loadingState == .loadingPurchase)

    state.loadingState = .manualLoading
    #expect(PaywallViewUpdate.endManualLoading.reduce(state).loadingState == .ready)
  }

  @Test("A claim binds its request, publisher and occurrence")
  func claimed() {
    let occurrence = TriggerAudienceOccurrence(key: "key", maxCount: 1, interval: .infinity)
    let claim = claim(occurrence: occurrence)
    var start = PaywallViewState(paywall: .stub())
    start.isPresentedBySDK = true
    let state = PaywallViewUpdate.claimed(claim, isHandedOut: false).reduce(start)
    #expect(state.request != nil)
    #expect(state.paywallStateSubject === claim.paywallStatePublisher)
    #expect(state.unsavedOccurrence == occurrence)
    #expect(state.currentClaim?.id == claim.id)
    #expect(state.handedOutClaim == nil)
    #expect(state.isPresentedBySDK == false)
  }

  @Test("A claim for another version of the paywall replaces it, and one for the same version updates it")
  func claimPaywall() {
    var other = Paywall.stub()
    other.cacheKey = "other"
    let start = PaywallViewState(paywall: .stub())
    let replaced = PaywallViewUpdate.claimed(claim(paywall: other), isHandedOut: false).reduce(start)
    #expect(replaced.paywall.cacheKey == "other")

    var sameVersion = Paywall.stub()
    sameVersion.presentationSourceType = "register"
    let updated = PaywallViewUpdate.claimed(claim(paywall: sameVersion), isHandedOut: false)
      .reduce(start)
    #expect(updated.paywall.cacheKey == start.paywall.cacheKey)
    #expect(updated.paywall.presentationSourceType == "register")
  }

  @Test("A handed out claim that's also current is cleared with it")
  func handedOutClaimFollowsCurrentClaim() {
    let occurrence = TriggerAudienceOccurrence(key: "key", maxCount: 1, interval: .infinity)
    let start = PaywallViewState(paywall: .stub())
    var state = PaywallViewUpdate.claimed(claim(occurrence: occurrence), isHandedOut: true)
      .reduce(start)
    #expect(state.handedOutClaim?.id == state.currentClaim?.id)
    #expect(state.handedOutClaimNeedsRestoring == false)

    state = PaywallViewUpdate.occurrenceSaved.reduce(state)
    #expect(state.unsavedOccurrence == nil)
    #expect(state.currentClaim?.unsavedOccurrence == nil)
    #expect(state.handedOutClaim?.unsavedOccurrence == nil)

    state = PaywallViewUpdate.paywallStatePublisherCompleted.reduce(state)
    #expect(state.paywallStateSubject == nil)
    #expect(state.handedOutClaim?.paywallStatePublisher == nil)

    // Restoring it installs a new publisher, since the old one completed.
    state = PaywallViewUpdate.claimed(claim(), isHandedOut: false).reduce(state)
    #expect(state.handedOutClaimNeedsRestoring)
    state = PaywallViewUpdate.handedOutClaimRestored.reduce(state)
    #expect(state.currentClaim?.id == state.handedOutClaim?.id)
    #expect(state.paywallStateSubject != nil)
    #expect(state.handedOutClaim?.paywallStatePublisher === state.paywallStateSubject)
    #expect(state.handedOutClaimNeedsRestoring == false)
  }

  @Test("A claim deferred while on screen waits to be restored")
  func deferredClaim() {
    let deferred = claim()
    let state = PaywallViewUpdate.handedOutClaimDeferred(deferred)
      .reduce(PaywallViewState(paywall: .stub()))
    #expect(state.handedOutClaim?.id == deferred.id)
    #expect(state.handedOutClaimNeedsRestoring)
    #expect(state.currentClaim == nil)
  }

  @Test("Presenting and dismissing")
  func presentationAndDismissal() {
    var state = PaywallViewState(paywall: .stub())
    state = PaywallViewUpdate.purchaseCompleted(.blank()).reduce(state)
    state = PaywallViewUpdate.delegateCalled.reduce(state)
    state = PaywallViewUpdate.presentationWillBegin.reduce(state)
    #expect(state.completedPurchaseProduct == nil)
    #expect(state.didCallDelegate == false)
    #expect(state.paywall.closeReason == .none)
    #expect(state.presentationWillPrepare)

    state = PaywallViewUpdate.presentationPrepared.reduce(state)
    state = PaywallViewUpdate.presented.reduce(state)
    #expect(state.presentationWillPrepare == false)
    #expect(state.isPresented)
    #expect(state.presentationDidFinishPrepare)

    var didComplete = false
    state = PaywallViewUpdate.dismissing(
      result: .declined,
      closeReason: .manualClose,
      completion: { didComplete = true }
    ).reduce(state)
    #expect(state.paywallResult == .declined)
    #expect(state.paywall.closeReason == .manualClose)
    state.dismissCompletionBlock?()
    #expect(didComplete)

    state = PaywallViewUpdate.dismissed.reduce(state)
    state = PaywallViewUpdate.presentationReset.reduce(state)
    #expect(state.paywallResult == nil)
    #expect(state.dismissCompletionBlock == nil)
    #expect(state.isPresented == false)
    #expect(state.presentationWillPrepare)
    #expect(state.presentationDidFinishPrepare == false)
  }

  @Test("The presentation style follows an override, else the paywall's")
  func presentationStyle() {
    let start = PaywallViewState(paywall: .stub())
    let overridden = PaywallViewUpdate.presentationStyle(override: .push).reduce(start)
    #expect(overridden.presentationStyle == .push)
    let none = PaywallViewUpdate.presentationStyle(override: PaywallPresentationStyle.none)
      .reduce(overridden)
    #expect(none.presentationStyle == start.paywall.presentation.style)

    var popup = start
    popup.presentationStyle = .popup(height: 50, width: 50, cornerRadius: 10)
    #expect(PaywallViewUpdate.embedded.reduce(popup).presentationStyle == .fullscreen)
    #expect(PaywallViewUpdate.embedded.reduce(overridden).presentationStyle == .push)
  }

  @Test("A web view load records only its first start")
  func webviewLoadStarted() {
    let first = Date(timeIntervalSince1970: 1)
    let state = PaywallViewUpdate.webviewLoadStarted(Date(timeIntervalSince1970: 2))
      .reduce(PaywallViewUpdate.webviewLoadStarted(first).reduce(PaywallViewState(paywall: .stub())))
    #expect(state.paywall.webviewLoadingInfo.startAt == first)
  }

  @Test("Closing the checkout sheet resets its flags, and is ready unless the SDK closed it")
  func checkoutClosed() {
    var state = PaywallViewState(paywall: .stub())
    state.loadingState = .loadingPurchase
    state = PaywallViewUpdate.safariPresented(true).reduce(state)
    #expect(state.isCheckoutSheetDismissalAnAbandon)

    let closedByBuyer = PaywallViewUpdate.checkoutClosed.reduce(state)
    #expect(closedByBuyer.loadingState == .ready)
    #expect(closedByBuyer.isSafariVCPresented == false)

    var closedBySDK = PaywallViewUpdate.checkoutDismissedProgrammatically.reduce(state)
    closedBySDK.loadingState = .manualLoading
    #expect(closedBySDK.isCheckoutSheetDismissalAnAbandon == false)
    closedBySDK = PaywallViewUpdate.checkoutClosed.reduce(closedBySDK)
    #expect(closedBySDK.loadingState == .manualLoading)
    #expect(closedBySDK.isCheckoutDismissedProgrammatically == false)

    var flagged = PaywallViewUpdate.redeemSucceededDuringCheckout.reduce(state)
    flagged = PaywallViewUpdate.stripeCheckoutAbandoned.reduce(flagged)
    flagged = PaywallViewUpdate.customStoreCheckoutSheetLeftOpen(true).reduce(flagged)
    let reopened = PaywallViewUpdate.checkoutOpened.reduce(flagged)
    #expect(reopened.isCheckoutSheetDismissalAnAbandon)
  }

  @Test("A completed Stripe checkout shows the spinner and isn't an abandon")
  func stripeCheckoutCompleted() {
    var state = PaywallViewState(paywall: .stub())
    state.loadingState = .ready
    state = PaywallViewUpdate.stripeCheckoutCompleted.reduce(state)
    #expect(state.loadingState == .manualLoading)
    #expect(state.isCheckoutSheetDismissalAnAbandon == false)
  }
}

@Suite("PaywallViewController store")
struct PaywallViewControllerStoreTests {
  /// The view controller holds its dependencies unowned and starts tasks that
  /// outlive the test, so anything it depends on lives for the whole process.
  private static var retained: [AnyObject] = []

  @MainActor
  private static func makeViewController() -> PaywallViewController {
    let container = DependencyContainer()
    retained.append(container)
    let messageHandler = PaywallMessageHandler(
      receiptManager: container.receiptManager,
      factory: container,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: container.customCallbackRegistry
    )
    let webView = SWWebView(
      isiOSAppOnMac: false,
      messageHandler: messageHandler,
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

    viewController.setLoadingState(.ready)
    #expect(viewController.loadingState == .ready)
    viewController.togglePaywallSpinner(isHidden: false)
    #expect(viewController.loadingState == .manualLoading)
    viewController.togglePaywallSpinner(isHidden: true)
    viewController.togglePaywallSpinner(isHidden: true)
    viewController.setLoadingState(.ready)

    // The repeated hide doesn't write, while setting the same state again
    // is still published.
    #expect(published == [.ready, .manualLoading, .ready, .ready])
  }

  @Test("200 concurrent loading state changes are published on the main thread in order")
  func concurrentUpdatesPublishInOrder() async {
    let states: [PaywallLoadingState] = [.loadingURL, .ready, .manualLoading, .loadingPurchase]
    let viewController = await MainActor.run { Self.makeViewController() }
    let store = await MainActor.run { viewController.viewStore }

    let lock = NSLock()
    var applied: [PaywallLoadingState] = []
    store.observe { before, after in
      guard after.loadingStatePublications != before.loadingStatePublications else {
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
      store.update(PaywallViewUpdate.loadingState(states[index % states.count]))
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
    let store = await MainActor.run { viewController.viewStore }
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
      viewController.setLoadingState(.ready)
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
