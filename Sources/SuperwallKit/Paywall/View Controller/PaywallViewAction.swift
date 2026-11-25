//
//  PaywallViewAction.swift
//  SuperwallKit
//
//  Created by Superwall on 06/11/2026.
//
// swiftlint:disable file_length strict_fileprivate

#if canImport(WebKit)
import Combine
import Foundation

typealias PaywallViewStore = StateStore<PaywallViewContext, PaywallViewState>

/// Everything the paywall view's actions can cause. ``PaywallViewController``
/// provides it in the SDK, and tests provide a fake that records the calls.
///
/// Actions run with the store locked, so they call the methods that may wait
/// or call into UIKit, the app or the page through ``effect(_:)``, which runs
/// them once the store is unlocked, in the order they were asked for. The
/// methods documented as called with the store locked only record a value.
protocol PaywallViewContext: AnyObject {
  var store: PaywallViewStore { get }
  /// The delegate that hears how the paywall finished, if any.
  var delegate: PaywallViewControllerDelegateAdapter? { get }
  /// Whether Safari or a checkout sheet is on screen over the paywall. Safari
  /// doesn't always report it closed, so the state alone can say one is open
  /// after it has gone.
  var isBrowserOnScreen: Bool { get }
  /// Whether the paywall, or a view controller it's inside, is being
  /// dismissed. Its view going away then is the paywall leaving, even with a
  /// browser over it.
  var isLeavingScreen: Bool { get }

  /// Publishes a loading state write. Called with the store locked, in the
  /// order the writes were made, and publishes them on the main thread once
  /// it's unlocked.
  func publishLoadingState(_ loadingState: PaywallLoadingState, from oldValue: PaywallLoadingState)

  // MARK: State publishers, held by the view controller. Called with the store locked.
  func registerStatePublisher(_ publisher: PassthroughSubject<PaywallState, Never>, forClaim id: UUID)
  /// Gives the claim a new publisher if its last one finished when the
  /// paywall was dismissed.
  func reopenStatePublisherIfFinished(forClaim id: UUID)
  /// Lets go of the publishers of claims that are no longer used.
  func keepStatePublishers(forClaims ids: Set<UUID>)
  func saveDismissCompletion(_ completion: @escaping () -> Void, forPresentation id: UUID)

  // MARK: Effects, run once the store is unlocked
  /// Sends `event` with `info`, the info of the presentation it's about.
  func sendState(_ event: PaywallViewStateEvent, toClaim id: UUID, info: PaywallInfo)
  func finishStatePublisher(forClaim id: UUID)
  func runDismissCompletion(forPresentation id: UUID)
  func storePresentationObjects(forClaim id: UUID?)
  func installDelegate(for request: PresentationRequest)
  func callDidFinish(_ result: PaywallResult, shouldDismiss: Bool)
  /// Tells `delegate`, the one a presentation began with, that it finished,
  /// for a dismissal that finished after the paywall was shown again.
  func callDidFinish(_ result: PaywallResult, to delegate: PaywallViewControllerDelegateAdapter?)
  func notifyWillPresent()
  func notifyDidPresent()
  func notifyWillDismiss()
  func notifyDidDismiss(info: PaywallInfo)
  func reloadWebView()
  func sendTemplateParams()
  func fetchIntroOfferTokens()
  func saveOccurrence(_ occurrence: TriggerAudienceOccurrence)
  func trackOpen()
  func trackClose()
  /// Marks the paywall as the one the cache has on screen, or not.
  func markActive(_ isActive: Bool)
  func destroyPresentingWindow()
  func listenToGameController(_ isListening: Bool)
  func restoreSwipeAfterSurvey()
  /// Tracks the Stripe checkout as abandoned shortly, unless cancelled.
  func scheduleCheckoutAbandonTracking()
  func cancelCheckoutAbandonTracking()
  /// Stores a teleport the page opened, so it can be recovered after a cold launch.
  func registerTeleportOpen(_ teleport: PendingTeleportState)
  /// Says the page won't report how this teleport went, so it's checked in the background.
  func teleportPageWentAway(_ teleportId: String)
  /// Tells the page's custom store checkout it has ended.
  func notifyCustomStoreCheckoutEnded()
}

/// A ``PaywallState`` an action sends, which the view controller fills in
/// with the paywall's info.
enum PaywallViewStateEvent: Equatable {
  case willDismiss(PaywallResult)
  case dismissed(PaywallResult)
}

extension PaywallViewContext {
  var state: PaywallViewState {
    store.state
  }

  func update(_ update: PaywallViewUpdate) {
    store.update(update)
  }

  /// Publishes every loading state write, whatever made it. Call it once,
  /// right after creating the store.
  func publishLoadingStateWrites() {
    store.observe { [weak self] before, after in
      if after.loadingStateWrites == before.loadingStateWrites {
        return
      }
      self?.publishLoadingState(after.loadingState, from: before.loadingState)
    }
  }

  /// Runs `work` once the store is unlocked.
  func effect(_ work: @escaping () -> Void) {
    store.deferUntilUnlocked(work)
  }

  @discardableResult
  func dispatch(_ action: PaywallViewAction) -> PaywallViewAction.Outcome {
    store.dispatch(action, in: self)
  }

  /// Lets go of the publishers of claims nothing uses anymore.
  fileprivate func pruneStatePublishers() {
    keepStatePublishers(forClaims: state.claimIdsInUse)
  }
}

/// What the paywall view does. The only place its side effects start.
// swiftlint:disable:next type_body_length
enum PaywallViewAction: StoreAction {
  typealias Context = PaywallViewContext

  /// What an action reports back, read in the same step as its update.
  enum Outcome: Equatable {
    case done
    /// The loading state after an event.
    case loadingState(PaywallLoadingState)
    /// Whether a claim started loading another version of the paywall.
    case loadStarted(Bool)
    /// Whether an appearance started a presentation.
    case presentationBegan(Bool)
    /// The dismissal a request resolved to.
    case dismissal(PaywallViewState.Dismissal)
    /// Whether the delegate was told the paywall finished.
    case finishReported(toDelegate: Bool)
    /// The presentation whose dismissal started finishing, if one did.
    case dismissalStarted(UUID?)
    /// Whether closing the checkout sheet abandoned a Stripe checkout.
    case checkoutClosed(wasAbandon: Bool)
    /// Whether the browser opened. It doesn't while another browser is open
    /// or closing, so the view controller doesn't present it.
    case browserOpened(Bool)
    /// The teleport a page's checkout report settled, if the paywall had one open.
    case teleportSettled(String?)

    var didStartLoad: Bool {
      if case .loadStarted(let didStart) = self {
        return didStart
      }
      return false
    }
  }

  /// Applies an event that has no side effects other than publishing the
  /// loading state.
  case event(PaywallViewUpdate)
  /// A request claims the view controller. A view controller that's on
  /// screen stays with the request that put it there, so the claim only
  /// waits, if it's a `getPaywall` one.
  case claim(
    PaywallViewState.Claim,
    publisher: PassthroughSubject<PaywallState, Never>,
    isHandedOut: Bool,
    isActive: Bool
  )
  /// The app is showing the view controller it got from `getPaywall`, and
  /// another request has claimed it since, so the app's claim is applied
  /// again. Only on an appearance that starts a presentation.
  case restoreHandedOutClaim
  /// The paywall started appearing. Starts a presentation, if it's not
  /// already on screen.
  case beginPresentation
  /// The paywall appeared.
  case finishAppearing
  case requestDismissal(
    result: PaywallResult,
    closeReason: PaywallCloseReason,
    completion: (() -> Void)?
  )
  /// Tells the delegate the paywall finished, if there's one, so it can
  /// dismiss it.
  case reportFinished(PaywallViewState.Dismissal)
  case willDisappear
  /// The paywall went off screen. Starts finishing its dismissal.
  case didDisappear
  /// The dismissal of the presentation with this id has saved the page's
  /// state, so it's reported.
  case finishDismissal(UUID)
  case endCustomStoreCheckout
  case openCheckout(UUID)
  case openSafari
  case closeCheckout(UUID)
  /// Asks for the presentation with this id to be dismissed, only while it's on screen, so
  /// a newer presentation of the same view controller is left alone. Returns `.done` when
  /// it has gone.
  case requestDismissalOfPresentation(
    UUID,
    result: PaywallResult,
    closeReason: PaywallCloseReason
  )
  case redeemSucceeded
  /// The page reported its Stripe checkout abandoned. Returns the teleport it settled.
  case stripeCheckoutAbandoned
  /// The page reported its Stripe checkout completed. Returns the teleport it settled.
  case stripeCheckoutCompleted
  /// The page opened a teleport in the browser.
  case teleportOpened(PendingTeleportState)
  /// The page started a checkout. A teleport it opened before is no longer the one it reports on.
  case stripeCheckoutStarted
  /// The page loaded again, so it has lost whatever it was keeping track of.
  case pageRestarted

  // swiftlint:disable:next function_body_length cyclomatic_complexity
  func execute(in context: PaywallViewContext) -> Outcome {
    switch self {
    case .event(let update):
      context.update(update)
      return .loadingState(context.state.loadingState)
    case let .claim(claim, publisher, isHandedOut, isActive):
      context.registerStatePublisher(publisher, forClaim: claim.id)
      if isActive {
        if isHandedOut {
          context.update(.handedOutClaimDeferred(claim))
        }
        context.pruneStatePublishers()
        return .loadStarted(false)
      }
      return .loadStarted(
        Self.apply(claim, with: .claimed(claim, isHandedOut: isHandedOut), in: context)
      )
    case .restoreHandedOutClaim:
      let state = context.state
      guard
        state.startsPresentationOnAppear,
        !state.isPresentedBySDK,
        case .awaitingRestore(let claim) = state.handedOut
      else {
        return .loadStarted(false)
      }
      context.reopenStatePublisherIfFinished(forClaim: claim.id)
      return .loadStarted(Self.apply(claim, with: .handedOutClaimRestored, in: context))
    case .beginPresentation:
      let state = context.state
      if !state.startsPresentationOnAppear {
        return .presentationBegan(false)
      }
      let presentation = Self.newPresentation(from: state, in: context)
      context.update(.presentationWillBegin(presentation))
      context.effect { context.fetchIntroOfferTokens() }
      context.dispatch(.endCustomStoreCheckout)
      context.effect { context.notifyWillPresent() }
      if state.loadingState == .ready {
        context.effect { context.sendTemplateParams() }
      }
      return .presentationBegan(true)
    case .finishAppearing:
      let state = context.state
      let presentation: PaywallViewState.Presentation
      if case .appearing(let appearing) = state.phase {
        presentation = appearing
        context.update(.presentationDidFinish)
      } else if state.startsPresentationOnAppear {
        presentation = Self.newPresentation(from: state, in: context)
        context.update(.appearedWithoutBeginning(presentation))
      } else {
        return .done
      }
      context.effect { context.storePresentationObjects(forClaim: presentation.claimId) }
      if let occurrence = state.unsavedOccurrence {
        context.effect { context.saveOccurrence(occurrence) }
        context.update(.occurrenceSaved)
      }
      context.effect {
        context.notifyDidPresent()
        context.trackOpen()
        context.listenToGameController(true)
      }
      return .done
    case let .requestDismissal(result, closeReason, completion):
      return Self.requestDismissal(
        result: result,
        closeReason: closeReason,
        completion: completion,
        in: context
      )
    case .reportFinished(let dismissal):
      if context.delegate == nil {
        return .finishReported(toDelegate: false)
      }
      context.update(.delegateCalled)
      context.effect { context.callDidFinish(dismissal.result, shouldDismiss: true) }
      return .finishReported(toDelegate: true)
    case .willDisappear:
      guard
        case .presented(let presentation) = context.state.phase,
        !Self.isCoveredByBrowser(in: context)
      else {
        return .done
      }
      Self.reportWillDismiss(of: presentation, in: context)
      return .done
    case .didDisappear:
      guard case .presented(let presentation) = context.state.phase else {
        return .dismissalStarted(nil)
      }
      // A browser still open here, with the paywall staying, was on screen at
      // `willDisappear`, which took the view going away for the browser
      // covering it.
      let didSkipWillDismiss = context.state.isBrowserOpen && !context.isLeavingScreen
      if Self.isCoveredByBrowser(in: context) {
        return .dismissalStarted(nil)
      }
      if didSkipWillDismiss {
        Self.reportWillDismiss(of: presentation, in: context)
      }
      context.effect { context.trackClose() }
      context.update(.disappeared)
      Self.leaveTeleportToBackground(in: context)
      return .dismissalStarted(presentation.id)
    case .finishDismissal(let id):
      Self.finishDismissal(id, in: context)
      return .done
    case .endCustomStoreCheckout:
      context.update(.customStoreCheckoutFinished)
      context.effect { context.notifyCustomStoreCheckoutEnded() }
      return .done
    case .openCheckout(let id):
      if Self.isBrowserInTheWay(in: context) {
        return .browserOpened(false)
      }
      context.update(.checkoutOpened(id))
      context.effect { context.cancelCheckoutAbandonTracking() }
      return .browserOpened(true)
    case .openSafari:
      if Self.isBrowserInTheWay(in: context) {
        return .browserOpened(false)
      }
      context.update(.safariOpened)
      return .browserOpened(true)
    case .closeCheckout(let id):
      let state = context.state
      guard let sheet = state.checkoutSheet(id) else {
        return .checkoutClosed(wasAbandon: false)
      }
      let isAbandon = state.isAbandon(closing: sheet)
      context.update(.checkoutClosed(id))
      if isAbandon {
        context.effect { context.scheduleCheckoutAbandonTracking() }
      }
      return .checkoutClosed(wasAbandon: isAbandon)
    case .redeemSucceeded:
      context.update(.redeemSucceeded)
      context.effect { context.cancelCheckoutAbandonTracking() }
      return .done
    case .stripeCheckoutAbandoned:
      let teleportId = context.state.unsettledTeleportId
      context.update(.stripeCheckoutAbandoned)
      context.effect { context.cancelCheckoutAbandonTracking() }
      return .teleportSettled(teleportId)
    case .stripeCheckoutCompleted:
      let teleportId = context.state.unsettledTeleportId
      context.update(.stripeCheckoutCompleted)
      return .teleportSettled(teleportId)
    case .teleportOpened(let teleport):
      context.update(.teleportOpened(teleport.teleportId))
      context.effect { context.registerTeleportOpen(teleport) }
      return .done
    case .stripeCheckoutStarted,
      .pageRestarted:
      Self.leaveTeleportToBackground(in: context)
      return .done
    case let .requestDismissalOfPresentation(id, result, closeReason):
      // One already being dismissed keeps the result it was dismissed with.
      guard
        case .presented(let presentation) = context.state.phase,
        presentation.id == id,
        presentation.dismissal == nil
      else {
        return .done
      }
      return Self.requestDismissal(result: result, closeReason: closeReason, completion: nil, in: context)
    }
  }

  /// Forgets the unsettled teleport, if there is one, and hands it to the background check.
  private static func leaveTeleportToBackground(in context: PaywallViewContext) {
    guard let teleportId = context.state.unsettledTeleportId else {
      return
    }
    context.update(.teleportLeftToBackground)
    context.effect { context.teleportPageWentAway(teleportId) }
  }

  /// Resolves a dismissal for the latest presentation, or saves it for the next one.
  private static func requestDismissal(
    result: PaywallResult,
    closeReason: PaywallCloseReason,
    completion: (() -> Void)?,
    in context: PaywallViewContext
  ) -> Outcome {
    let state = context.state
    let dismissal = state.resolvedDismissal(result: result, closeReason: closeReason)
    let presentationId: UUID
    if let presentation = state.latestPresentation {
      presentationId = presentation.id
      context.update(.dismissRequested(dismissal))
    } else {
      presentationId = state.earlyDismissal?.presentationId ?? UUID()
      context.update(
        .earlyDismissRequested(
          PaywallViewState.EarlyDismissal(presentationId: presentationId, dismissal: dismissal)
        )
      )
    }
    if let completion = completion {
      context.saveDismissCompletion(completion, forPresentation: presentationId)
    }
    return .dismissal(dismissal)
  }

  /// Applies a claim with `update`, installing its delegate first so anything
  /// the reload announces goes to the claim that owns it. Returns whether it
  /// started loading another version of the paywall.
  private static func apply(
    _ claim: PaywallViewState.Claim,
    with update: PaywallViewUpdate,
    in context: PaywallViewContext
  ) -> Bool {
    let loadedCacheKey = context.state.paywall.cacheKey
    context.effect { context.installDelegate(for: claim.request) }
    context.update(update)
    context.pruneStatePublishers()
    if context.state.paywall.cacheKey == loadedCacheKey {
      return false
    }
    // The request resolved a different version of the paywall from the one
    // loaded, so show that version rather than only its products.
    context.effect { context.reloadWebView() }
    return true
  }

  /// A presentation starting now. It takes the id of a dismissal asked for
  /// before it, and finishes with that dismissal's result. Its close reason
  /// starts over, as a presentation's does.
  private static func newPresentation(
    from state: PaywallViewState,
    in context: PaywallViewContext
  ) -> PaywallViewState.Presentation {
    var presentation = PaywallViewState.Presentation(
      id: state.earlyDismissal?.presentationId ?? UUID(),
      isPresentedBySDK: state.isPresentedBySDK,
      claimId: state.currentClaim?.id,
      request: state.currentClaim?.request,
      delegate: context.delegate
    )
    if let early = state.earlyDismissal {
      presentation.dismissal = PaywallViewState.Dismissal(
        result: early.dismissal.result,
        closeReason: .none
      )
    }
    return presentation
  }

  /// Whether the paywall's view going away is a browser covering it, not a
  /// dismissal. A checkout sheet the SDK is closing doesn't count: the paywall
  /// can be dismissed while it animates away.
  private static func isCoveredByBrowser(in context: PaywallViewContext) -> Bool {
    if !context.state.isBrowserOpen {
      return false
    }
    if context.isLeavingScreen {
      // The paywall is dismissed together with its browser. Safari goes
      // without reporting it, so it's forgotten here. A checkout sheet reports
      // its own close.
      if context.state.browser == .safari {
        context.update(.browserWentUnreported)
      }
      return false
    }
    return isBrowserInTheWay(in: context)
  }

  private static func reportWillDismiss(
    of presentation: PaywallViewState.Presentation,
    in context: PaywallViewContext
  ) {
    let result = presentation.dismissal?.result ?? .declined
    let info = context.state.dismissalInfo(for: presentation)
    context.effect {
      if let claimId = presentation.claimId {
        context.sendState(.willDismiss(result), toClaim: claimId, info: info)
      }
      context.notifyWillDismiss()
    }
  }

  /// Whether a browser is open, so another can't be. A browser the state has
  /// open that isn't on screen went without reporting it, as Safari does when
  /// the app dismisses it, and is forgotten.
  private static func isBrowserInTheWay(in context: PaywallViewContext) -> Bool {
    if context.state.browser == .none {
      return false
    }
    if context.isBrowserOnScreen {
      return true
    }
    context.update(.browserWentUnreported)
    return false
  }

  /// Reports the end of a presentation. If a new presentation started while
  /// this one's dismissal was finishing, only this one's subscribers,
  /// completion and delegate hear about it: the paywall on screen is left as
  /// it is.
  private static func finishDismissal(_ id: UUID, in context: PaywallViewContext) {
    let state = context.state
    guard let presentation = state.finishingDismissal(id) else {
      return
    }
    var isLatest = false
    if case .dismissing(let latest) = state.phase {
      isLatest = latest.id == id
    }
    let result = presentation.dismissal?.result ?? .declined
    let closeReason = presentation.dismissal?.closeReason ?? .none
    let claimId = presentation.claimId
    let info = state.dismissalInfo(for: presentation)

    context.update(.dismissalFinished(id))
    // The survey's swipe block stays on the view controller after it's
    // dismissed, so it's undone even when the paywall is already showing
    // again, unless that presentation blocked the swipe for its own survey.
    let restoresSwipe = presentation.isSwipeDisabledForSurvey
      && context.state.activePresentation?.isSwipeDisabledForSurvey != true
    if isLatest {
      context.effect {
        context.destroyPresentingWindow()
        context.listenToGameController(false)
        if restoresSwipe {
          context.restoreSwipeAfterSurvey()
        }
      }
      context.dispatch(.endCustomStoreCheckout)
      context.effect { context.markActive(false) }
    } else if restoresSwipe {
      context.effect { context.restoreSwipeAfterSurvey() }
    }

    // Another presentation of the same claim, on screen or still finishing
    // its own dismissal, still sends on its publisher.
    let isPublisherInUse = claimId.map(context.state.unfinishedPresentationClaimIds.contains) ?? false
    context.effect {
      context.runDismissCompletion(forPresentation: id)
      if let claimId = claimId {
        context.sendState(.dismissed(result), toClaim: claimId, info: info)
      }
      if !presentation.didCallDelegate {
        if isLatest {
          context.callDidFinish(result, shouldDismiss: false)
        } else {
          context.callDidFinish(result, to: presentation.delegate)
        }
      }
      if closeReason.stateShouldComplete,
        let claimId = claimId,
        !isPublisherInUse {
        context.finishStatePublisher(forClaim: claimId)
      }
      context.notifyDidDismiss(info: info)
      // After the sends above, which still need this presentation's publisher.
      context.pruneStatePublishers()
    }
  }
}

extension PaywallViewState {
  /// The presentation on screen, starting, or finishing its dismissal.
  var latestPresentation: Presentation? {
    if case .dismissing(let presentation) = phase {
      return presentation
    }
    return activePresentation
  }

  /// The claims of presentations that haven't finished: the one on screen,
  /// starting or dismissing, and those whose dismissal is still finishing.
  var unfinishedPresentationClaimIds: Set<UUID> {
    var ids = Set<UUID>()
    if let id = latestPresentation?.claimId {
      ids.insert(id)
    }
    for presentation in supersededDismissals {
      if let id = presentation.claimId {
        ids.insert(id)
      }
    }
    return ids
  }

  /// The claims whose publishers are still needed: the current one, one
  /// waiting to be restored, and those of presentations still reporting.
  var claimIdsInUse: Set<UUID> {
    var ids = unfinishedPresentationClaimIds
    if let id = currentClaim?.id {
      ids.insert(id)
    }
    if case .awaitingRestore(let claim) = handedOut {
      ids.insert(claim.id)
    }
    return ids
  }

  /// The checkout sheet with this id, open or closing.
  func checkoutSheet(_ id: UUID) -> CheckoutSheet? {
    switch browser {
    case .checkout(let sheet),
      .closingCheckout(let sheet):
      return sheet.id == id ? sheet : nil
    case .none,
      .safari:
      return nil
    }
  }
}
#endif
