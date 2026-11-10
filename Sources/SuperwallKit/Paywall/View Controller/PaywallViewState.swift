//
//  PaywallViewState.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//
// swiftlint:disable file_length strict_fileprivate

#if canImport(WebKit)
import Foundation

/// What ``PaywallViewController`` knows about its paywall and presentation.
/// Changed only by ``PaywallViewUpdate`` reducers on its store.
///
/// Views, timers, tasks, publishers, completion blocks and other objects the
/// view controller drives stay on the view controller, which is the store's
/// ``PaywallViewContext``. This holds the values its decisions are made from.
struct PaywallViewState {
  /// What a request applies when it claims the view controller.
  struct Claim {
    /// Tells claims apart, so their state publishers, which the view
    /// controller holds, can be found.
    let id: UUID
    let request: PresentationRequest
    let paywall: Paywall
    /// Saved when the presentation that uses the claim appears, then cleared,
    /// so restoring the claim later doesn't save it again.
    var unsavedOccurrence: TriggerAudienceOccurrence?

    init(
      id: UUID = UUID(),
      request: PresentationRequest,
      paywall: Paywall,
      unsavedOccurrence: TriggerAudienceOccurrence?
    ) {
      self.id = id
      self.request = request
      self.paywall = paywall
      self.unsavedOccurrence = unsavedOccurrence
    }
  }

  /// The claim made through `getPaywall`. It's kept so that a view controller
  /// the app is holding reports that placement when the app shows it, even if
  /// the SDK presented this paywall for another placement in the meantime.
  ///
  /// It's held for the life of the cached view controller on purpose: the app
  /// can show the handle it was given at any time.
  enum HandedOut {
    case none
    /// The handed out claim is the current claim.
    case current
    /// Another claim replaced it, so the app showing the view controller
    /// applies it again.
    case awaitingRestore(Claim)
  }

  /// One time the paywall is on screen, from its first appearance until its
  /// dismissal has finished.
  struct Presentation {
    let id: UUID
    /// Whether the SDK presented it, rather than the app showing a view
    /// controller it got from `getPaywall`.
    let isPresentedBySDK: Bool
    /// The claim the presentation reports to.
    let claimId: UUID?
    /// The request and delegate when it began. A dismissal that finishes
    /// after the paywall was shown again reports with these, as the view
    /// controller's may belong to the new presentation.
    let request: PresentationRequest?
    let delegate: PaywallViewControllerDelegateAdapter?
    /// Whether the delegate has been told the presentation finished.
    var didCallDelegate = false
    /// Whether swiping the paywall away is blocked so a survey can show.
    var isSwipeDisabledForSurvey = false
    /// Set once something asks for the paywall to be dismissed.
    var dismissal: Dismissal?
    #if os(macOS)
    /// Whether the SDK is dismissing it, or it's animating out of an overlay.
    var isClosing = false
    /// Whether it went off screen with its window, which was minimised or
    /// hidden with the app, and hasn't come back yet.
    var isHiddenWithWindow = false
    #endif

    init(
      id: UUID = UUID(),
      isPresentedBySDK: Bool,
      claimId: UUID?,
      request: PresentationRequest? = nil,
      delegate: PaywallViewControllerDelegateAdapter? = nil
    ) {
      self.id = id
      self.isPresentedBySDK = isPresentedBySDK
      self.claimId = claimId
      self.request = request
      self.delegate = delegate
    }
  }

  /// How a presentation was asked to end.
  struct Dismissal: Equatable {
    let result: PaywallResult
    let closeReason: PaywallCloseReason
  }

  /// A dismissal asked for before the paywall started appearing. The next
  /// presentation takes its id, so a completion saved for it runs when that
  /// presentation is dismissed, and finishes with its result.
  struct EarlyDismissal: Equatable {
    let presentationId: UUID
    let dismissal: Dismissal
  }

  enum Phase {
    /// Not on screen. Its next appearance starts a presentation.
    case idle
    /// The SDK has asked for it to be shown, and it hasn't started appearing.
    case requested
    /// It has started appearing.
    case appearing(Presentation)
    /// It has appeared.
    case presented(Presentation)
    /// It has gone off screen and its dismissal is finishing. A new
    /// presentation can start meanwhile, which moves this one to
    /// ``PaywallViewState/supersededDismissals``.
    case dismissing(Presentation)
  }

  /// What the paywall has open in app.
  enum Browser: Equatable {
    case none
    case safari
    case checkout(CheckoutSheet)
    /// The SDK closed the checkout sheet, which reports when it has gone.
    case closingCheckout(CheckoutSheet)
  }

  /// A checkout sheet, and why closing it isn't an abandoned Stripe checkout,
  /// once something makes it so.
  struct CheckoutSheet: Equatable {
    enum Settled: Equatable {
      /// A redeem succeeded while it was open.
      case redeemed
      /// The page reported the checkout completed or abandoned.
      case pageReportedOutcome
      /// A custom store checkout ended while it stayed open, as one that
      /// timed out does.
      case customStoreCheckoutEnded
      /// The SDK closed it, as it does when a redemption starts.
      case closedBySDK
    }

    let id: UUID
    var settled: Settled?
  }

  var paywall: Paywall
  var presentationStyle: PaywallPresentationStyle
  var loadingState: PaywallLoadingState = .unknown
  /// Counts the loading state writes, which are all published, even one that
  /// leaves it as it was.
  var loadingStateWrites = 0
  /// The claim currently applied to the view controller.
  var currentClaim: Claim?
  var handedOut: HandedOut = .none
  var phase: Phase = .idle
  /// A dismissal asked for while nothing was on screen or starting, which
  /// the next presentation takes.
  var earlyDismissal: EarlyDismissal?
  /// Presentations whose dismissal is still finishing after a new
  /// presentation started. Each finishes for itself only, without touching
  /// the one on screen.
  var supersededDismissals: [Presentation] = []
  var browser: Browser = .none
  /// The custom product whose checkout the paywall is running, if any. The
  /// paywall reports how that checkout ends, so closing its sheet isn't
  /// tracked as an abandoned Stripe checkout.
  var customStoreCheckoutProductId: String?
  /// The product bought since the last presentation began, App Store or web.
  /// A close that follows a purchase, such as a `close` among the button's
  /// after-purchase actions, finishes the presentation as purchased.
  var completedPurchase: StoreProduct?
  /// Whether a popup is animating out after a tap on its background.
  var isPopupBackgroundDismissing = false
  /// When the paywall was last opened, until it's closed.
  var lastOpen: Date?
  /// Whether the survey was shown, not shown, or in a holdout.
  var surveyPresentationResult: SurveyPresentationResult = .noShow

  init(paywall: Paywall) {
    self.paywall = paywall
    self.presentationStyle = paywall.presentation.style
  }

  // MARK: Derived values

  var request: PresentationRequest? {
    currentClaim?.request
  }

  var unsavedOccurrence: TriggerAudienceOccurrence? {
    currentClaim?.unsavedOccurrence
  }

  /// The presentation on screen or starting, not one finishing its dismissal.
  var activePresentation: Presentation? {
    switch phase {
    case .appearing(let presentation),
      .presented(let presentation):
      return presentation
    case .idle,
      .requested,
      .dismissing:
      return nil
    }
  }

  /// The info a presentation's dismissal reports: its own placement and
  /// close reason, even if the paywall has been shown again since.
  func dismissalInfo(for presentation: Presentation) -> PaywallInfo {
    var paywall = paywall
    paywall.closeReason = presentation.dismissal?.closeReason ?? paywall.closeReason
    return paywall.getInfo(fromPlacement: presentation.request?.presentationInfo.placementData)
  }

  /// Whether the paywall has appeared and its dismissal hasn't finished.
  var isPresented: Bool {
    switch phase {
    case .presented,
      .dismissing:
      return true
    case .idle,
      .requested,
      .appearing:
      return false
    }
  }

  /// Whether the next appearance starts a presentation.
  var startsPresentationOnAppear: Bool {
    switch phase {
    case .idle,
      .requested,
      .dismissing:
      return true
    case .appearing,
      .presented:
      return false
    }
  }

  /// Whether the SDK asked for the paywall to be shown, for the appearance
  /// about to start or the one on screen.
  var isPresentedBySDK: Bool {
    switch phase {
    case .requested:
      return true
    case .appearing(let presentation),
      .presented(let presentation):
      return presentation.isPresentedBySDK
    case .idle,
      .dismissing:
      return false
    }
  }

  var isBrowserOpen: Bool {
    switch browser {
    case .safari,
      .checkout:
      return true
    case .none,
      .closingCheckout:
      return false
    }
  }

  /// Whether the paywall's spinner is showing.
  var isShowingSpinner: Bool {
    return loadingState == .loadingPurchase || loadingState == .manualLoading
  }

  #if os(macOS)
  var isClosing: Bool {
    activePresentation?.isClosing ?? false
  }

  var isHiddenWithWindow: Bool {
    activePresentation?.isHiddenWithWindow ?? false
  }

  /// From when the SDK starts presenting until the paywall appears: the span
  /// UIKit reports through `isBeingPresented`, which AppKit doesn't have.
  var isBeingPresented: Bool {
    switch phase {
    case .requested,
      .appearing:
      return true
    case .idle,
      .presented,
      .dismissing:
      return false
    }
  }
  #endif

  /// Whether the buyer closing this checkout sheet abandons a Stripe
  /// checkout: nothing settled it, and it isn't a custom store checkout,
  /// whose outcome the page reports.
  func isAbandon(closing sheet: CheckoutSheet) -> Bool {
    return sheet.settled == nil && customStoreCheckoutProductId == nil
  }

  /// The result a dismissal reports: a decline after a completed purchase is
  /// a purchase. A close to show the next paywall stays as it is, so that
  /// paywall keeps the presentation's state.
  func resolvedDismissal(
    result: PaywallResult,
    closeReason: PaywallCloseReason
  ) -> Dismissal {
    if closeReason == .forNextPaywall {
      return Dismissal(result: result, closeReason: closeReason)
    }
    if result == .declined, let product = completedPurchase {
      return Dismissal(result: .purchased(product), closeReason: .systemLogic)
    }
    return Dismissal(result: result, closeReason: closeReason)
  }
}

/// A change to the loading state, named for what happened.
enum PaywallLoadingChange: Equatable {
  /// The web view started loading the page.
  case webViewLoadStarted
  /// The page finished loading. A spinner showing for something else, such
  /// as a Stripe recovery, stays up.
  case webContentLoaded
  case purchaseStarted
  /// The SDK started work the buyer waits on, such as a redemption.
  case manualLoadingStarted
  /// What the buyer was waiting on finished.
  case finished
  /// The app or page asked for the spinner, which shows if the paywall is ready.
  case spinnerRequested
  /// The app or page asked to hide the spinner, if it's showing.
  case spinnerDismissed
  /// Manual loading finished. A purchase's spinner stays up.
  case manualLoadingEnded

  /// The loading state this change writes, or `nil` if it leaves it alone.
  func loadingState(after current: PaywallLoadingState) -> PaywallLoadingState? {
    switch self {
    case .webViewLoadStarted:
      return .loadingURL
    case .webContentLoaded:
      return current == .manualLoading ? nil : .ready
    case .purchaseStarted:
      return .loadingPurchase
    case .manualLoadingStarted:
      return .manualLoading
    case .finished:
      return .ready
    case .spinnerRequested:
      return current == .ready ? .manualLoading : nil
    case .spinnerDismissed:
      return current == .manualLoading || current == .loadingPurchase ? .ready : nil
    case .manualLoadingEnded:
      return current == .manualLoading ? .ready : nil
    }
  }
}

/// The ways ``PaywallViewState`` can change.
enum PaywallViewUpdate: Reducer {
  // MARK: Paywall
  /// The SDK fetched a new version of the paywall for this view controller.
  case paywallReplaced(Paywall)
  case presentationStyleChosen(override: PaywallPresentationStyle?)
  /// A popup embedded in the app's view fills it like the fullscreen style.
  case embedded
  case webViewLoadStarted(Date)
  case webViewLoadEnded(Date)
  case webViewLoadFailed(Date)
  case paywallJSVersionReceived(String?)
  case shimmerStarted(Date)
  case shimmerEnded(Date)
  /// The page's state, saved on dismissal.
  case pageStateSaved([String: Any])
  case loading(PaywallLoadingChange)

  // MARK: Claims
  /// A request claimed the view controller while it wasn't on screen.
  case claimed(PaywallViewState.Claim, isHandedOut: Bool)
  /// `getPaywall` claimed the view controller while it was on screen, so the
  /// claim waits until the app shows it.
  case handedOutClaimDeferred(PaywallViewState.Claim)
  /// The app is showing the view controller it got from `getPaywall`, so
  /// that claim is applied again.
  case handedOutClaimRestored
  /// The current claim's audience occurrence has been saved.
  case occurrenceSaved

  // MARK: Presentation
  case sdkPresentationRequested
  case presentationWillBegin(PaywallViewState.Presentation)
  case presentationDidFinish
  case dismissRequested(PaywallViewState.Dismissal)
  /// Something asked for the paywall to be dismissed before it started
  /// appearing.
  case earlyDismissRequested(PaywallViewState.EarlyDismissal)
  /// The paywall appeared without having started appearing, as when UIKit
  /// calls `viewDidAppear` without `viewWillAppear`.
  case appearedWithoutBeginning(PaywallViewState.Presentation)
  case surveyFinished(SurveyPresentationResult)
  case delegateCalled
  /// The paywall went off screen and its dismissal started finishing.
  case disappeared
  /// The dismissal of the presentation with this id finished.
  case dismissalFinished(UUID)
  /// Swiping the paywall away is blocked so its survey can show.
  case surveySwipeBlocked
  case purchaseCompleted(StoreProduct)
  case opened(Date)
  case closed
  case popupBackgroundTapped
  case popupBackgroundAnimationEnded

  // MARK: Browser and checkout
  case safariOpened
  case safariClosed
  case checkoutOpened(UUID)
  /// The checkout sheet with this id has gone.
  case checkoutClosed(UUID)
  /// The SDK closed whatever was open in app.
  case browserClosedBySDK
  /// Whatever was open in app has gone without reporting it.
  case browserWentUnreported
  case redeemSucceeded
  case stripeCheckoutAbandoned
  /// The page reported a Stripe checkout completed: it isn't an abandon, and
  /// the spinner shows while the purchase finishes.
  case stripeCheckoutCompleted
  /// A custom store checkout moved on a step.
  case customStoreCheckoutAdvanced(productId: String?, closesBrowser: Bool)
  case customStoreCheckoutFinished

  #if os(macOS)
  // MARK: macOS
  case macCloseStarted
  case macCloseEnded
  case hidWithWindow
  case cameBackWithWindow
  #endif

  // swiftlint:disable:next function_body_length cyclomatic_complexity
  func reduce(_ state: PaywallViewState) -> PaywallViewState {
    var state = state
    switch self {
    case .paywallReplaced(let paywall):
      state.paywall = paywall
    case .presentationStyleChosen(let override):
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
    case .webViewLoadStarted(let date):
      if state.paywall.webviewLoadingInfo.startAt == nil {
        state.paywall.webviewLoadingInfo.startAt = date
      }
      state.writeLoadingState(.loadingURL)
    case .webViewLoadEnded(let date):
      state.paywall.webviewLoadingInfo.endAt = date
    case .webViewLoadFailed(let date):
      state.paywall.webviewLoadingInfo.failAt = date
    case .paywallJSVersionReceived(let version):
      state.paywall.paywalljsVersion = version
    case .shimmerStarted(let date):
      state.paywall.shimmerLoadingInfo.startAt = date
    case .shimmerEnded(let date):
      state.paywall.shimmerLoadingInfo.endAt = date
    case .pageStateSaved(let pageState):
      state.paywall.state = pageState
    case .loading(let change):
      if let loadingState = change.loadingState(after: state.loadingState) {
        state.writeLoadingState(loadingState)
      }
    case let .claimed(claim, isHandedOut):
      let previous = state.currentClaim
      state.apply(claim)
      if case .requested = state.phase {
        state.phase = .idle
      }
      if isHandedOut {
        state.handedOut = .current
      } else if case .current = state.handedOut,
        let previous = previous {
        state.handedOut = .awaitingRestore(previous)
      }
    case .handedOutClaimDeferred(let claim):
      state.handedOut = .awaitingRestore(claim)
    case .handedOutClaimRestored:
      if case .awaitingRestore(let claim) = state.handedOut {
        state.apply(claim)
        state.handedOut = .current
      }
    case .occurrenceSaved:
      state.currentClaim?.unsavedOccurrence = nil
    case .sdkPresentationRequested:
      if state.startsPresentationOnAppear {
        state.supersedeFinishingDismissal()
        state.phase = .requested
      }
    case .presentationWillBegin(let presentation):
      state.supersedeFinishingDismissal()
      state.phase = .appearing(presentation)
      state.earlyDismissal = nil
      state.paywall.closeReason = .none
      // A purchase belongs to the presentation it was made in. It's cleared
      // here rather than when the view disappears: a sheet swiped away
      // disappears before its close is reported.
      state.completedPurchase = nil
    case .presentationDidFinish:
      if case .appearing(let presentation) = state.phase {
        state.phase = .presented(presentation)
      }
    case .earlyDismissRequested(let earlyDismissal):
      state.paywall.closeReason = earlyDismissal.dismissal.closeReason
      state.earlyDismissal = earlyDismissal
    case .appearedWithoutBeginning(let presentation):
      state.supersedeFinishingDismissal()
      state.phase = .presented(presentation)
      state.earlyDismissal = nil
    case .dismissRequested(let dismissal):
      // A sheet swiped away asks to be dismissed after it has gone, so this
      // also reaches a presentation whose dismissal is finishing.
      state.paywall.closeReason = dismissal.closeReason
      state.updateLatestPresentation { $0.dismissal = dismissal }
    case .surveyFinished(let result):
      state.surveyPresentationResult = result
    case .delegateCalled:
      state.updateLatestPresentation { $0.didCallDelegate = true }
    case .disappeared:
      if case .presented(let presentation) = state.phase {
        state.phase = .dismissing(presentation)
      }
    case .dismissalFinished(let id):
      if case .dismissing(let presentation) = state.phase,
        presentation.id == id {
        state.phase = .idle
      }
      state.supersededDismissals.removeAll { $0.id == id }
    case .surveySwipeBlocked:
      state.updateActivePresentation { $0.isSwipeDisabledForSurvey = true }
    case .purchaseCompleted(let product):
      state.completedPurchase = product
    case .opened(let date):
      state.lastOpen = date
    case .closed:
      state.lastOpen = nil
    case .popupBackgroundTapped:
      state.isPopupBackgroundDismissing = true
    case .popupBackgroundAnimationEnded:
      state.isPopupBackgroundDismissing = false
    case .safariOpened:
      if state.browser == .none {
        state.browser = .safari
      }
    case .safariClosed:
      if state.browser == .safari {
        state.browser = .none
      }
    case .checkoutOpened(let id):
      if state.browser == .none {
        state.browser = .checkout(PaywallViewState.CheckoutSheet(id: id))
      }
    case .checkoutClosed(let id):
      switch state.browser {
      case .checkout(let sheet),
        .closingCheckout(let sheet):
        if sheet.id == id {
          state.browser = .none
          if sheet.settled != .closedBySDK {
            state.writeLoadingState(.ready)
          }
        }
      case .none,
        .safari:
        break
      }
    case .browserClosedBySDK:
      switch state.browser {
      case .checkout(var sheet):
        sheet.settled = .closedBySDK
        state.browser = .closingCheckout(sheet)
      case .safari:
        state.browser = .none
      case .none,
        .closingCheckout:
        break
      }
    case .browserWentUnreported:
      state.browser = .none
    case .redeemSucceeded:
      state.settleCheckout(.redeemed)
    case .stripeCheckoutAbandoned:
      state.settleCheckout(.pageReportedOutcome)
    case .stripeCheckoutCompleted:
      state.settleCheckout(.pageReportedOutcome)
      state.writeLoadingState(.manualLoading)
    case let .customStoreCheckoutAdvanced(productId, closesBrowser):
      state.customStoreCheckoutProductId = productId
      if !closesBrowser {
        // The checkout already ended, so the buyer closing its sheet later
        // abandons nothing.
        state.settleCheckout(.customStoreCheckoutEnded)
      }
    case .customStoreCheckoutFinished:
      state.customStoreCheckoutProductId = nil
    #if os(macOS)
    case .macCloseStarted:
      state.updateActivePresentation { $0.isClosing = true }
    case .macCloseEnded:
      state.updateActivePresentation { $0.isClosing = false }
    case .hidWithWindow:
      state.updateActivePresentation { $0.isHiddenWithWindow = true }
    case .cameBackWithWindow:
      state.updateActivePresentation { $0.isHiddenWithWindow = false }
    #endif
    }
    return state
  }
}

extension PaywallViewState {
  /// Applies a claim's request, occurrence and paywall. A version of the
  /// paywall with the same cache key only updates the loaded one, while a
  /// different version replaces it.
  fileprivate mutating func apply(_ claim: Claim) {
    currentClaim = claim
    if claim.paywall.cacheKey == paywall.cacheKey {
      paywall.update(from: claim.paywall)
    } else {
      paywall = claim.paywall
    }
  }

  /// The presentation whose dismissal is finishing, with this id, whether
  /// it's still the latest or a new one has started since.
  func finishingDismissal(_ id: UUID) -> Presentation? {
    if case .dismissing(let presentation) = phase,
      presentation.id == id {
      return presentation
    }
    return supersededDismissals.first { $0.id == id }
  }

  /// Changes the presentation on screen, starting, or finishing its
  /// dismissal.
  fileprivate mutating func updateLatestPresentation(_ change: (inout Presentation) -> Void) {
    if case .dismissing(var presentation) = phase {
      change(&presentation)
      phase = .dismissing(presentation)
      return
    }
    updateActivePresentation(change)
  }

  fileprivate mutating func updateActivePresentation(_ change: (inout Presentation) -> Void) {
    switch phase {
    case .appearing(var presentation):
      change(&presentation)
      phase = .appearing(presentation)
    case .presented(var presentation):
      change(&presentation)
      phase = .presented(presentation)
    case .idle,
      .requested,
      .dismissing:
      break
    }
  }

  /// Moves a presentation whose dismissal is finishing aside, so it can
  /// finish for itself once another presentation starts.
  fileprivate mutating func supersedeFinishingDismissal() {
    if case .dismissing(let presentation) = phase {
      supersededDismissals.append(presentation)
    }
  }

  fileprivate mutating func writeLoadingState(_ state: PaywallLoadingState) {
    loadingState = state
    loadingStateWrites += 1
  }

  /// Settles the open checkout sheet, unless something settled it already.
  fileprivate mutating func settleCheckout(_ settled: CheckoutSheet.Settled) {
    guard case .checkout(var sheet) = browser,
      sheet.settled == nil else {
      return
    }
    sheet.settled = settled
    browser = .checkout(sheet)
  }
}
#endif
