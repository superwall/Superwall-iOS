//
//  PaywallViewState.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//
// swiftlint:disable file_length

import Combine
import Foundation

/// Holds ``PaywallViewState``. It has no store actions: the view controller
/// runs on the main thread and does its UIKit work itself, outside the store.
typealias PaywallViewStore = StateStore<Void, PaywallViewState>

/// What ``PaywallViewController`` knows about its paywall and presentation.
/// Changed only by ``PaywallViewUpdate`` reducers on its store.
///
/// Views, timers, tasks and other objects the view controller drives stay on
/// the view controller. This holds the values its decisions are made from.
struct PaywallViewState {
  /// What a request applies when it claims the view controller.
  ///
  /// The occurrence and publisher are cleared once used, so restoring the
  /// claim later doesn't save the occurrence again or reinstall a publisher
  /// that has already completed.
  struct Claim {
    /// Tells the current claim and the handed out one apart, as the same
    /// claim can be both.
    let id = UUID()
    let request: PresentationRequest
    let paywall: Paywall
    var paywallStatePublisher: PassthroughSubject<PaywallState, Never>?
    var unsavedOccurrence: TriggerAudienceOccurrence?
  }

  // MARK: Paywall and request
  var paywall: Paywall
  /// The request associated with the presentation of the paywall.
  var request: PresentationRequest?
  var presentationStyle: PaywallPresentationStyle
  /// Sends the ``PaywallState``s of the current presentation to the caller of
  /// `register`. Set when a claim is applied.
  var paywallStateSubject: PassthroughSubject<PaywallState, Never>?
  /// If the user matches an audience with an occurrence, this needs to be
  /// saved on paywall presentation.
  var unsavedOccurrence: TriggerAudienceOccurrence?
  /// The claim currently applied to the view controller.
  var currentClaim: Claim?
  /// The claim made through `getPaywall`. Kept so that a view controller the
  /// app is holding reports that placement when the app shows it, even if the
  /// SDK presented this paywall for another placement in the meantime.
  ///
  /// This is held for the life of the cached view controller on purpose: the
  /// app can show the handle it was given at any time.
  var handedOutClaim: Claim?
  /// Whether the SDK claimed the view controller after it was handed out.
  var handedOutClaimNeedsRestoring = false

  // MARK: Loading
  var loadingState: PaywallLoadingState = .unknown
  /// Counts the loading state writes the view controller publishes. Its
  /// observer sends whenever this changes, so a write is published even when
  /// it leaves the loading state as it was.
  var loadingStatePublications = 0

  // MARK: Presentation
  /// Whether the paywall has finished appearing and not yet been dismissed.
  var isPresented = false
  /// Whether the SDK started the current presentation via `present(on:...)`.
  var isPresentedBySDK = false
  /// Whether the next appearance starts a presentation.
  var presentationWillPrepare = true
  /// Whether the current presentation has finished appearing.
  var presentationDidFinishPrepare = false
  /// Whether the delegate has been told the presentation finished.
  var didCallDelegate = false
  /// `true` if there's a survey to complete and the paywall is displayed in a
  /// modal style.
  var didDisableSwipeForSurvey = false
  /// Whether a popup is animating out after a tap on its background.
  var isCustomBackgroundDismissal = false
  /// When the paywall was last opened.
  var lastOpen: Date?

  // MARK: Dismissal
  /// The result the paywall is being dismissed with.
  var paywallResult: PaywallResult?
  /// Runs once the paywall has been dismissed.
  var dismissCompletionBlock: (() -> Void)?
  /// Whether the survey was shown, not shown, or in a holdout.
  var surveyPresentationResult: SurveyPresentationResult = .noShow
  /// The product bought from this presentation, App Store or web. A close
  /// that follows a purchase finishes the presentation as purchased rather
  /// than declined.
  var completedPurchaseProduct: StoreProduct?

  // MARK: Browser and checkout
  /// Whether Safari or the checkout sheet is open in app.
  var isSafariVCPresented = false
  /// Whether a redeem succeeded while the checkout sheet is open.
  var didRedeemSucceedDuringCheckout = false
  /// Whether the SDK is closing the checkout sheet.
  var isCheckoutDismissedProgrammatically = false
  /// Whether the page reported the Stripe checkout abandoned or completed.
  var didReceiveStripeCheckoutAbandonMessage = false
  /// The custom product whose checkout the paywall is running, if any.
  var customStoreCheckoutProductId: String?
  /// Whether the open checkout sheet belongs to a custom store checkout that
  /// ended while it stayed open, as one that timed out does.
  var isCustomStoreCheckoutSheetLeftOpen = false

  #if os(macOS)
  // MARK: macOS
  /// From when the SDK starts presenting until the paywall appears.
  var isMacPresentationInFlight = false
  /// Whether the paywall went off screen with its window and hasn't come back.
  var isHiddenWithWindow = false
  /// Whether the SDK is dismissing the paywall, or it's animating out of an
  /// overlay.
  var isClosing = false
  #endif

  init(paywall: Paywall) {
    self.paywall = paywall
    self.presentationStyle = paywall.presentation.style
  }

  /// Whether the paywall's spinner is showing.
  var isShowingSpinner: Bool {
    return loadingState == .loadingPurchase || loadingState == .manualLoading
  }

  /// Whether the buyer closing the checkout sheet abandons a Stripe checkout:
  /// no redeem succeeded, the SDK didn't close it, the page didn't report the
  /// abandon itself, and it isn't a custom store checkout, whose outcome the
  /// page reports.
  var isCheckoutSheetDismissalAnAbandon: Bool {
    return !didRedeemSucceedDuringCheckout
      && !isCheckoutDismissedProgrammatically
      && customStoreCheckoutProductId == nil
      && !isCustomStoreCheckoutSheetLeftOpen
      && !didReceiveStripeCheckoutAbandonMessage
  }
}

/// The ways ``PaywallViewState`` can change.
enum PaywallViewUpdate: Reducer {
  // MARK: Paywall and request
  /// Replaces the paywall.
  case paywall(Paywall)
  /// A request claimed the view controller while it wasn't on screen.
  case claimed(PaywallViewState.Claim, isHandedOut: Bool)
  /// `getPaywall` claimed the view controller while it was on screen, so the
  /// claim waits until the app shows it.
  case handedOutClaimDeferred(PaywallViewState.Claim)
  /// The app is showing the view controller it got from `getPaywall`, so
  /// that claim is applied again.
  case handedOutClaimRestored
  /// The claim's audience occurrence has been saved.
  case occurrenceSaved
  /// The presentation's state publisher completed.
  case paywallStatePublisherCompleted
  case presentationStyle(override: PaywallPresentationStyle?)
  /// A popup embedded in the app's view fills it like the fullscreen style.
  case embedded
  case webviewLoadStarted(Date)
  case shimmerStarted(Date)
  case shimmerEnded(Date)
  /// The page's state, saved on dismissal.
  case pageState([String: Any])

  // MARK: Loading
  case loadingState(PaywallLoadingState)
  /// Shows the spinner, if the paywall is ready.
  case showSpinner
  /// Hides the spinner, if it's showing.
  case hideSpinner
  /// Hides the spinner, if it's showing for something other than a purchase.
  case endManualLoading

  // MARK: Presentation
  case presentedBySDK
  case presentationWillBegin
  case presentationPrepared
  case presented
  case presentationReset
  case lastOpen(Date?)
  case swipeDisabledForSurvey(Bool)
  case customBackgroundDismissal(Bool)

  // MARK: Dismissal
  case dismissing(
    result: PaywallResult,
    closeReason: PaywallCloseReason,
    completion: (() -> Void)?
  )
  case surveyPresentationResult(SurveyPresentationResult)
  case delegateCalled
  case dismissed
  case purchaseCompleted(StoreProduct)

  // MARK: Browser and checkout
  case safariPresented(Bool)
  /// A checkout sheet opened, which starts a new checkout flow.
  case checkoutOpened
  /// The checkout sheet closed. Its loading state is ready unless the SDK
  /// closed it, as it does when a redeem starts.
  case checkoutClosed
  case checkoutDismissedProgrammatically
  case redeemSucceededDuringCheckout
  case stripeCheckoutAbandoned
  case stripeCheckoutCompleted
  case customStoreCheckoutProductId(String?)
  case customStoreCheckoutSheetLeftOpen(Bool)

  #if os(macOS)
  // MARK: macOS
  case macPresentationInFlight(Bool)
  case hiddenWithWindow(Bool)
  case closing(Bool)
  #endif

  // swiftlint:disable:next function_body_length
  func reduce(_ state: PaywallViewState) -> PaywallViewState {
    var state = state
    switch self {
    case .paywall(let paywall):
      state.paywall = paywall
    case let .claimed(claim, isHandedOut):
      state = state.applying(claim)
      state.isPresentedBySDK = false
      if isHandedOut {
        state.handedOutClaim = state.currentClaim
        state.handedOutClaimNeedsRestoring = false
      } else if state.handedOutClaim != nil {
        state.handedOutClaimNeedsRestoring = true
      }
    case .handedOutClaimDeferred(let claim):
      state.handedOutClaim = claim
      state.handedOutClaimNeedsRestoring = true
    case .handedOutClaimRestored:
      if let claim = state.handedOutClaim {
        state = state.applying(claim)
      }
      state.handedOutClaimNeedsRestoring = false
    case .occurrenceSaved:
      state.unsavedOccurrence = nil
      state.updateCurrentClaim { $0.unsavedOccurrence = nil }
    case .paywallStatePublisherCompleted:
      state.paywallStateSubject = nil
      state.updateCurrentClaim { $0.paywallStatePublisher = nil }
    case .presentationStyle(let override):
      if let override = override,
        override != .none {
        state.presentationStyle = override
      } else {
        state.presentationStyle = state.paywall.presentation.style
      }
    case .embedded:
      if case .popup = state.presentationStyle {
        state.presentationStyle = .fullscreen
      }
    case .webviewLoadStarted(let date):
      if state.paywall.webviewLoadingInfo.startAt == nil {
        state.paywall.webviewLoadingInfo.startAt = date
      }
    case .shimmerStarted(let date):
      state.paywall.shimmerLoadingInfo.startAt = date
    case .shimmerEnded(let date):
      state.paywall.shimmerLoadingInfo.endAt = date
    case .pageState(let pageState):
      state.paywall.state = pageState
    case .loadingState(let loadingState):
      state.setLoadingState(loadingState)
    case .showSpinner:
      if state.loadingState == .ready {
        state.setLoadingState(.manualLoading)
      }
    case .hideSpinner:
      if state.isShowingSpinner {
        state.setLoadingState(.ready)
      }
    case .endManualLoading:
      if state.loadingState == .manualLoading {
        state.setLoadingState(.ready)
      }
    case .presentedBySDK:
      state.isPresentedBySDK = true
    case .presentationWillBegin:
      state.didCallDelegate = false
      state.paywall.closeReason = .none
      // A purchase belongs to the presentation it was made in. It's cleared
      // here rather than when the view disappears: a sheet swiped away
      // disappears before its close is reported.
      state.completedPurchaseProduct = nil
    case .presentationPrepared:
      state.presentationWillPrepare = false
    case .presented:
      state.isPresented = true
      state.presentationDidFinishPrepare = true
    case .presentationReset:
      state.presentationWillPrepare = true
      state.presentationDidFinishPrepare = false
    case .lastOpen(let date):
      state.lastOpen = date
    case .swipeDisabledForSurvey(let isDisabled):
      state.didDisableSwipeForSurvey = isDisabled
    case .customBackgroundDismissal(let isDismissing):
      state.isCustomBackgroundDismissal = isDismissing
    case let .dismissing(result, closeReason, completion):
      state.paywallResult = result
      state.paywall.closeReason = closeReason
      state.dismissCompletionBlock = completion
    case .surveyPresentationResult(let result):
      state.surveyPresentationResult = result
    case .delegateCalled:
      state.didCallDelegate = true
    case .dismissed:
      state.paywallResult = nil
      state.dismissCompletionBlock = nil
      state.isPresented = false
      state.isPresentedBySDK = false
    case .purchaseCompleted(let product):
      state.completedPurchaseProduct = product
    case .safariPresented(let isPresented):
      state.isSafariVCPresented = isPresented
    case .checkoutOpened:
      state.didRedeemSucceedDuringCheckout = false
      state.isCheckoutDismissedProgrammatically = false
      state.didReceiveStripeCheckoutAbandonMessage = false
      state.isCustomStoreCheckoutSheetLeftOpen = false
    case .checkoutClosed:
      state.isSafariVCPresented = false
      if !state.isCheckoutDismissedProgrammatically {
        state.setLoadingState(.ready)
      }
      state.isCustomStoreCheckoutSheetLeftOpen = false
      state.didRedeemSucceedDuringCheckout = false
      state.isCheckoutDismissedProgrammatically = false
      state.didReceiveStripeCheckoutAbandonMessage = false
    case .checkoutDismissedProgrammatically:
      state.isCheckoutDismissedProgrammatically = true
    case .redeemSucceededDuringCheckout:
      state.didRedeemSucceedDuringCheckout = true
    case .stripeCheckoutAbandoned:
      state.didReceiveStripeCheckoutAbandonMessage = true
    case .stripeCheckoutCompleted:
      state.didReceiveStripeCheckoutAbandonMessage = true
      state.setLoadingState(.manualLoading)
    case .customStoreCheckoutProductId(let productId):
      state.customStoreCheckoutProductId = productId
    case .customStoreCheckoutSheetLeftOpen(let isLeftOpen):
      state.isCustomStoreCheckoutSheetLeftOpen = isLeftOpen
    #if os(macOS)
    case .macPresentationInFlight(let isInFlight):
      state.isMacPresentationInFlight = isInFlight
    case .hiddenWithWindow(let isHidden):
      state.isHiddenWithWindow = isHidden
    case .closing(let isClosing):
      state.isClosing = isClosing
    #endif
    }
    return state
  }
}

extension PaywallViewState {
  /// Applies a claim: binds its request, publisher and occurrence, and its
  /// paywall. A version of the paywall with the same cache key only updates
  /// the loaded one, while a different version replaces it.
  // swiftlint:disable:next strict_fileprivate
  fileprivate func applying(_ claim: Claim) -> PaywallViewState {
    var state = self
    var claim = claim
    if claim.paywallStatePublisher == nil {
      // The previous one completed when the paywall was last dismissed.
      claim.paywallStatePublisher = PassthroughSubject()
    }
    state.request = claim.request
    state.paywallStateSubject = claim.paywallStatePublisher
    state.unsavedOccurrence = claim.unsavedOccurrence
    state.currentClaim = claim
    if state.handedOutClaim?.id == claim.id {
      state.handedOutClaim = claim
    }

    if claim.paywall.cacheKey == state.paywall.cacheKey {
      state.paywall.update(from: claim.paywall)
    } else {
      state.paywall = claim.paywall
    }
    return state
  }

  /// Changes the current claim, and the handed out claim too when it's the
  /// same one.
  // swiftlint:disable:next strict_fileprivate
  fileprivate mutating func updateCurrentClaim(_ change: (inout Claim) -> Void) {
    guard var claim = currentClaim else {
      return
    }
    change(&claim)
    currentClaim = claim
    if handedOutClaim?.id == claim.id {
      handedOutClaim = claim
    }
  }

  // swiftlint:disable:next strict_fileprivate
  fileprivate mutating func setLoadingState(_ state: PaywallLoadingState) {
    loadingState = state
    loadingStatePublications += 1
  }
}
