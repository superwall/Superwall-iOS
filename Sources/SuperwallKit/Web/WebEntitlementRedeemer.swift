//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/03/2025.
//
// swiftlint:disable type_body_length function_body_length trailing_closure file_length

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// How a web checkout the paywall reported as complete finishes once its code is redeemed.
/// Stored with the pending checkout, so a poll that recovers it later finishes it the same way.
enum StripeCheckoutCompletion: Equatable, Codable {
  /// Legacy: the paywall hears `restore_complete`, and the paywall dismisses
  /// as `.restored` once its entitlements are active.
  case restore
  /// Like an App Store purchase: the paywall hears `transaction_complete`, so
  /// the button's after-purchase actions run, and it dismisses as
  /// `.purchased` only when `shouldDismiss` is true.
  case purchase(productId: String, shouldDismiss: Bool)
}

/// Redeems existing codes after a successful purchase.
protocol PostPurchaseRedeeming: Sendable {
  func redeemAfterPurchase() async
}

actor WebEntitlementRedeemer: PostPurchaseRedeeming {
  private let network: Network
  private let storage: Storage
  private let entitlementsInfo: EntitlementsInfo
  private let delegate: SuperwallDelegateAdapter
  private let purchaseController: PurchaseController
  private let receiptManager: ReceiptManager
  private unowned let factory: Factory
  private let notificationScheduler: NotificationScheduling
  private let stripePendingPollIntervalNs: UInt64
  private let stripePendingPollTimeoutNs: UInt64
  private var isProcessing = false
  /// The throttled entitlements poll in flight, which concurrent polls wait on.
  private var inFlightWebEntitlementsPoll: Task<Void, Never>?
  /// The order of responses that carry entitlements, and which of them last saved its
  /// customer info. A fetch takes its place when it's sent, as does a redeem of existing
  /// codes; a code redemption takes it when it arrives, since it changed the entitlements.
  /// An older response never replaces a newer one's customer info.
  private var entitlementsFetchCount = 0
  private var lastSavedEntitlementsFetch = 0
  private var hasActiveStripePoll = false
  private var lastCompletedStripePollResult: (contextId: String, outcome: StripePollOutcome)?
  private var awaitingCheckoutComplete = false
  /// The checkout the paywall last reported complete, while it's being finished. An older
  /// checkout's poll stops for it, so it doesn't wait behind a poll that can't redeem it.
  private var completingCheckoutContextId: String?
  /// Teleports whose page is still there to finish them: opened since the app launched, by a
  /// paywall that hasn't been closed or had its page loaded again since. The background check
  /// leaves these to the page.
  private var teleportsWithPage: Set<String> = []
  /// The checkout each teleport that read paid led to. The teleport is forgotten once that
  /// checkout is redeemed, or can't be.
  private var paidTeleportCheckouts: [String: String] = [:]
  /// How long a return link that doesn't say how to finish its purchase waits for the page on
  /// screen to report the purchase itself, which does say.
  private let pageReportWaitNs: UInt64
  /// The checkouts a paywall page has reported as completed or abandoned. A report it repeats
  /// settles no teleport, since the page may have opened another one since.
  private var checkoutsReportedByPage: Set<String> = []
  /// The checkouts a paywall page has started: an embedded one under its own id, a teleport
  /// under the teleport's. A report about one of them says nothing about a teleport opened
  /// under another id.
  private var checkoutsStartedByPage: Set<String> = []
  private var isCheckingPendingTeleport = false
  /// Teleports whose unpaid checkout was already looked at again since the app launched or
  /// last came to the foreground. Each gets one background round of rechecks each time, so a
  /// payment made while the app was away is found, and any other look costs one status read.
  private var teleportsRecheckedSinceForeground: Set<String> = []
  /// The background round of rechecks for a teleport whose checkout isn't paid yet.
  private var claimedTeleportRecheck: Task<Bool, Never>?
  /// How long to wait before each new look at a teleport whose checkout was started but isn't
  /// paid yet. The backend can mark the payment a second or two after the app is back.
  private let claimedTeleportRecheckDelays: [TimeInterval]
  /// The latest polls this session that brought newly active web entitlements, oldest first.
  /// A paywall whose audience was evaluated before one of them was let through without its
  /// entitlements, so it closes as restored once it opens if they newly cover it.
  private(set) var webEntitlementsArrivals: [WebEntitlementsArrival] = []
  /// How many arrivals are kept. Only a paywall loading when one came needs it.
  private static let keptArrivals = 10
  /// The presentations already told that they were restored, so each is told once.
  private var restoredPresentations: Set<UUID> = []
  var lastWebEntitlementsArrival: WebEntitlementsArrival? {
    webEntitlementsArrivals.last
  }
  private var superwall: Superwall?
  typealias Factory = WebEntitlementFactory
    & OptionsFactory
    & ConfigStateFactory
    & HasExternalPurchaseControllerFactory
    & DeviceHelperFactory
    & TestModeManagerFactory
    & PurchasedTransactionsFactory

  private enum StripePollTrigger: String {
    case checkoutComplete = "checkout_complete"
    case paywallOpen = "paywall_open"
    case foreground = "foreground"
  }

  private enum StripePollOutcome {
    case redeemed
    case checkoutFailed
    case noRedemptionFound
    case requestFailed
    case skippedInFlight
  }

  private enum RedemptionCallbackMode {
    case legacy
    case pollFakeCompatibility
  }

  var isCurrentlyProcessing: Bool {
    isProcessing
  }

  enum RedeemType: CustomStringConvertible {
    case code(String)
    case existingCodes
    case integrationAttributes

    /// Whether the redeem changes the user's entitlements on the server.
    var redeemsNewCode: Bool {
      if case .code = self {
        return true
      }
      return false
    }

    var description: String {
      switch self {
      case .code:
        return "CODE"
      case .existingCodes:
        return "EXISTING_CODES"
      case .integrationAttributes:
        return "INTEGRATION_ATTRIBUTES"
      }
    }

    var code: String? {
      switch self {
      case .code(let code):
        return code
      default:
        return nil
      }
    }
  }

  init(
    network: Network,
    storage: Storage,
    entitlementsInfo: EntitlementsInfo,
    delegate: SuperwallDelegateAdapter,
    purchaseController: PurchaseController,
    receiptManager: ReceiptManager,
    factory: Factory,
    notificationScheduler: NotificationScheduling = NotificationScheduler.shared,
    stripePendingPollIntervalNs: UInt64 = 1_500_000_000,
    stripePendingPollTimeoutNs: UInt64 = 60_000_000_000,
    claimedTeleportRecheckDelays: [TimeInterval] = [2, 3, 5],
    pageReportWaitNs: UInt64 = 5_000_000_000,
    superwall: Superwall? = nil
  ) {
    self.network = network
    self.storage = storage
    self.entitlementsInfo = entitlementsInfo
    self.delegate = delegate
    self.purchaseController = purchaseController
    self.factory = factory
    self.notificationScheduler = notificationScheduler
    self.superwall = superwall
    self.receiptManager = receiptManager
    self.stripePendingPollIntervalNs = stripePendingPollIntervalNs
    self.stripePendingPollTimeoutNs = stripePendingPollTimeoutNs
    self.claimedTeleportRecheckDelays = claimedTeleportRecheckDelays
    self.pageReportWaitNs = pageReportWaitNs

    // Observe when the app enters the foreground
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppForeground),
      name: SystemInfo.applicationWillEnterForegroundNotification,
      object: nil
    )
  }

  /// Checks once on SDK initialization so pending Stripe checkouts can be
  /// recovered on cold launch.
  ///
  /// Called by `Superwall` after the dependency container is fully built,
  /// rather than from this actor's own `init`: the poll reads container state
  /// from a background task, so it must not start while the container is
  /// still being set up.
  nonisolated func pollPendingStripeCheckoutOnColdLaunch() {
    Task {
      // A teleport the app was ended during is checked first: if it was paid, finishing it
      // polls its checkout, which replaces any older pending one.
      if await recoverPendingTeleport() {
        return
      }
      await pollPendingStripeCheckoutOnForegroundIfNeeded()
    }
  }

  /// The paywall opened a teleport in Safari. Kept until the page settles it or a background
  /// check reads how it went, so it can be finished if iOS ends the app meanwhile. Nothing is
  /// blocked by it: a paywall only waits once the check reads it paid.
  func registerTeleportOpen(_ teleport: PendingTeleportState) {
    teleportsWithPage.insert(teleport.teleportId)
    storage.save(teleport, forType: PendingTeleportStorage.self)
  }

  /// The paywall that opened the teleport was closed, or its page loaded again, so the page
  /// won't report how the teleport went. The background check takes over and looks now: the
  /// user may already be back, with no foreground left to wait for.
  func teleportPageWentAway(_ teleportId: String) {
    teleportsWithPage.remove(teleportId)
    guard storage.get(PendingTeleportStorage.self)?.teleportId == teleportId else {
      return
    }
    Task {
      await recoverPendingTeleport()
    }
  }

  /// The paywall page started a checkout.
  func registerStripeCheckoutStart(contextId: String) {
    checkoutsStartedByPage.insert(contextId)
  }

  /// Reads the status of the teleport left open, if there is one, without blocking anything.
  /// Only a paid teleport is finished, as a purchased return link would be: the paywall gets the
  /// spinner, the code is redeemed and the paywall closes. It's kept until that code is redeemed,
  /// so a redemption that fails is tried again. A teleport whose checkout was started
  /// (`claimed`) asks the checkout itself, as the page does, since the backend only marks the
  /// teleport paid once the checkout page reports back, seconds after the payment. Unpaid, it's
  /// kept for the next launch or foreground until its time limit, and looked at again a few
  /// times in the background, once per launch and per foreground, without making the caller
  /// wait. A `pending` teleport is kept too, since the user may still pay. `expired` or an
  /// unknown status forgets it; a failed request keeps it.
  ///
  /// - Parameter onForeground: Whether the app just came to the foreground. The user may have
  ///   paid while it was away, so an unpaid checkout gets a new round of rechecks.
  /// - Returns: `true` if the teleport was paid and its checkout polled.
  @discardableResult
  func recoverPendingTeleport(onForeground: Bool = false) async -> Bool {
    guard let teleport = storage.get(PendingTeleportStorage.self) else {
      return false
    }
    guard !teleport.hasExpired() else {
      clearPendingTeleport(teleport.teleportId)
      return false
    }
    // The page that opened it is still on screen and finishes it when the user is back.
    if await isStoredTeleportWithItsPage() {
      return false
    }
    guard !isCheckingPendingTeleport else {
      return false
    }
    if onForeground {
      teleportsRecheckedSinceForeground.removeAll()
    }
    isCheckingPendingTeleport = true
    switch await readPendingTeleport(teleport) {
    case .paid(let purchase):
      isCheckingPendingTeleport = false
      await finishPaidTeleport(purchase)
      return true
    case .settled,
      .notStarted,
      .unknown:
      isCheckingPendingTeleport = false
      return false
    case .checkoutStarted:
      guard
        !claimedTeleportRecheckDelays.isEmpty,
        teleportsRecheckedSinceForeground.insert(teleport.teleportId).inserted
      else {
        isCheckingPendingTeleport = false
        return false
      }
      // The rechecks keep the check flag until they finish, so nothing reads it twice meanwhile.
      claimedTeleportRecheck = Task { [weak self] in
        guard let self else { return false }
        return await self.recheckClaimedTeleport(teleport)
      }
      return false
    }
  }

  /// Waits for the background round of rechecks started by ``recoverPendingTeleport()``, if one
  /// runs. Returns `true` if it found the teleport paid and polled its checkout.
  func waitForClaimedTeleportRecheck() async -> Bool {
    await claimedTeleportRecheck?.value ?? false
  }

  private func recheckClaimedTeleport(_ teleport: PendingTeleportState) async -> Bool {
    defer { isCheckingPendingTeleport = false }
    for delay in claimedTeleportRecheckDelays {
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      // The page settled it, or a newer teleport replaced it, while this waited.
      guard storage.get(PendingTeleportStorage.self)?.teleportId == teleport.teleportId else {
        return false
      }
      switch await readPendingTeleport(teleport) {
      case .paid(let purchase):
        isCheckingPendingTeleport = false
        await finishPaidTeleport(purchase)
        return true
      case .settled,
        .notStarted,
        .unknown:
        return false
      case .checkoutStarted:
        continue
      }
    }
    return false
  }

  /// Polls a paid teleport's checkout. The poll forgets the teleport when it redeems the
  /// checkout; so does this when the page had redeemed it already.
  private func finishPaidTeleport(_ purchase: PurchasedReturn) async {
    await handlePurchasedReturn(purchase)
    if isRedeemed(purchase.checkoutContextId) {
      clearTeleport(paidFor: purchase.checkoutContextId)
    }
  }

  private enum PendingTeleportReading {
    /// Paid: the purchase to finish. The teleport is kept until its checkout is redeemed.
    case paid(PurchasedReturn)
    /// A checkout was started and isn't paid yet. The teleport is kept and looked at again.
    case checkoutStarted
    /// No checkout was started yet. The teleport is kept for the next launch or foreground.
    case notStarted
    /// Not paid and never will be, or replaced. The teleport is forgotten.
    case settled
    /// The request failed. The teleport is kept.
    case unknown
  }

  private func readPendingTeleport(_ teleport: PendingTeleportState) async -> PendingTeleportReading {
    let status: TeleportStatusResponse
    do {
      status = try await network.getTeleportStatus(teleportId: teleport.teleportId)
    } catch {
      Logger.debug(
        logLevel: .warn,
        scope: .webEntitlements,
        message: "Checking the teleport left open failed; checking again later",
        error: error
      )
      return .unknown
    }
    let checkoutContextId = status.checkoutContextId.flatMap { $0.isEmpty ? nil : $0 }
    var isPaid = status.isCompleted && checkoutContextId != nil
    if !isPaid, status.isClaimed, let checkoutContextId {
      do {
        isPaid = try await network.getCheckoutStatus(checkoutId: checkoutContextId).isCompleted
      } catch {
        Logger.debug(
          logLevel: .warn,
          scope: .webEntitlements,
          message: "Checking the checkout of the teleport left open failed; checking again later",
          error: error
        )
        return .unknown
      }
    }
    // The page settled it, or a newer teleport replaced it, while the status was read.
    guard storage.get(PendingTeleportStorage.self)?.teleportId == teleport.teleportId else {
      return .settled
    }
    rememberCheckout(checkoutContextId, startedBy: teleport)
    if isPaid, let checkoutContextId {
      paidTeleportCheckouts[checkoutContextId] = teleport.teleportId
      return .paid(
        teleport.purchase(
          checkoutContextId: checkoutContextId,
          productId: status.checkoutProductIdentifier
        )
      )
    }
    if status.isClaimed, checkoutContextId != nil {
      return .checkoutStarted
    }
    // Not opened yet, or Safari is still on the teleport page: the user may still pay, so it's
    // kept for the next launch or foreground until its time limit.
    if status.isPending {
      return .notStarted
    }
    clearPendingTeleport(teleport.teleportId)
    return .settled
  }

  /// Forgets the stored teleport, but only if it's this one, so a newer teleport stays.
  private func clearPendingTeleport(_ teleportId: String?) {
    guard let teleportId else {
      return
    }
    teleportsWithPage.remove(teleportId)
    if storage.get(PendingTeleportStorage.self)?.teleportId == teleportId {
      storage.delete(PendingTeleportStorage.self)
    }
  }

  /// The page heard how its teleport went, so there's nothing left to check in the background.
  /// Only on its first report of a checkout, and only when that checkout can be the teleport's.
  /// A report it repeats, or one about another checkout it started, may come after it opened
  /// this teleport: the teleport is kept and checked in the background, as the paywall no
  /// longer waits to hear about it.
  private func settleTeleport(_ teleportId: String?, reportedCheckout contextId: String?) {
    let isRepeated = contextId.map { !checkoutsReportedByPage.insert($0).inserted } ?? false
    guard let teleportId else {
      return
    }
    // A teleport's checkout is made in the browser, so the page never started it under an id
    // other than the teleport's.
    let isAnotherCheckout = contextId.map {
      $0 != teleportId && checkoutsStartedByPage.contains($0)
    } ?? false
    if isRepeated || isAnotherCheckout {
      teleportPageWentAway(teleportId)
      return
    }
    clearPendingTeleport(teleportId)
  }

  /// Forgets the teleport that led to this checkout, once the checkout is redeemed or can't be.
  private func clearTeleport(paidFor checkoutContextId: String) {
    clearPendingTeleport(paidTeleportCheckouts.removeValue(forKey: checkoutContextId))
  }

  /// Whether the page that opened the stored teleport is still on screen to finish it.
  private func isStoredTeleportWithItsPage() async -> Bool {
    guard
      let teleport = storage.get(PendingTeleportStorage.self),
      teleportsWithPage.contains(teleport.teleportId)
    else {
      return false
    }
    return await hasVisiblePaywall()
  }

  private func hasVisiblePaywall() async -> Bool {
    #if canImport(WebKit)
    let superwall = superwall ?? Superwall.shared
    return await MainActor.run { superwall.paywallViewController != nil }
    #else
    return false
    #endif
  }

  func registerStripeCheckoutSubmit(
    contextId: String,
    productId: String
  ) {
    awaitingCheckoutComplete = true
    savePendingStripeCheckoutState(
      .init(
        checkoutContextId: contextId,
        productId: productId
      )
    )
  }

  func shouldShowStripeRecoveryLoadingOnPaywallOpen() -> Bool {
    guard let state = pendingStripeCheckoutState else {
      return false
    }
    guard state.remainingForegroundAttempts > 0 else {
      clearPendingStripeCheckoutState()
      return false
    }
    if hasStripePendingTimedOut(state) {
      clearPendingStripeCheckoutState()
      return false
    }
    return true
  }

  private func isRedeemed(_ contextId: String) -> Bool {
    lastCompletedStripePollResult?.contextId == contextId
      && lastCompletedStripePollResult?.outcome == .redeemed
  }

  private func waitForActiveStripePoll() async {
    let waitStart = DispatchTime.now().uptimeNanoseconds
    while hasActiveStripePoll, !Task.isCancelled {
      if DispatchTime.now().uptimeNanoseconds - waitStart >= stripePendingPollTimeoutNs {
        return
      }
      try? await Task.sleep(nanoseconds: 100_000_000)
    }
  }

  /// Either starts a new poll or waits for an existing in-flight poll to
  /// finish. Returns `true` if the checkout was redeemed.
  func pollOrWaitForActiveStripePoll() async -> Bool {
    guard let pendingState = pendingStripeCheckoutState else {
      return false
    }
    let waitingContextId = pendingState.checkoutContextId

    // If there's already an active poll (e.g. from cold-launch init task),
    // wait for it to finish rather than skipping.
    if hasActiveStripePoll {
      await waitForActiveStripePoll()
      if hasActiveStripePoll || Task.isCancelled {
        return false
      }
      if let completed = lastCompletedStripePollResult,
        completed.contextId == waitingContextId {
        return completed.outcome == .redeemed
      }
      return false
    }

    // No active poll — start our own.
    return await pollPendingStripeCheckoutOnPaywallOpenIfNeeded()
  }

  func pollPendingStripeCheckoutOnPaywallOpenIfNeeded() async -> Bool {
    guard let pendingState = pendingStripeCheckoutState else {
      return false
    }
    guard pendingState.remainingForegroundAttempts > 0 else {
      clearPendingStripeCheckoutState()
      return false
    }

    let outcome = await pollStripeRedemptionResult(
      contextId: pendingState.checkoutContextId,
      productId: pendingState.productId,
      trigger: .paywallOpen,
      completion: pendingState.completion
    )

    return outcome == .redeemed
  }

  #if canImport(WebKit)
  func handleStripeCheckoutComplete(
    contextId: String,
    productId: String,
    completion: StripeCheckoutCompletion = .restore,
    settlingTeleportId: String? = nil
  ) async {
    awaitingCheckoutComplete = false
    settleTeleport(settlingTeleportId, reportedCheckout: contextId)

    // The page can report one purchase more than once (its status poll and the return check).
    // Redeemed once is enough: a second redemption would put the spinner back up behind the
    // success alert, with nothing left to take it down.
    if isRedeemed(contextId) {
      let superwall = self.superwall ?? Superwall.shared
      await MainActor.run {
        // The success alert's close takes the spinner down once the purchase is finished.
        let paywallViewController = superwall.paywallViewController
        #if os(macOS)
        // AppKit alerts are window sheets, not presented view controllers.
        let isShowingAlert = paywallViewController?.view.window?.attachedSheet != nil
        #else
        let isShowingAlert = paywallViewController?.presentedViewController is UIAlertController
        #endif
        if !isShowingAlert {
          paywallViewController?.updateLoading(.finished)
        }
      }
      return
    }

    completingCheckoutContextId = contextId
    defer {
      if completingCheckoutContextId == contextId {
        completingCheckoutContextId = nil
      }
    }

    if let existingState = pendingStripeCheckoutState,
      existingState.checkoutContextId == contextId {
      savePendingStripeCheckoutState(
        .init(
          checkoutContextId: contextId,
          productId: productId,
          completion: completion,
          isPaid: existingState.isPaid,
          remainingForegroundAttempts: existingState.remainingForegroundAttempts
        )
      )
    } else {
      savePendingStripeCheckoutState(
        .init(
          checkoutContextId: contextId,
          productId: productId,
          completion: completion
        )
      )
    }

    var outcome = await pollStripeRedemptionResult(
      contextId: contextId,
      productId: productId,
      trigger: .checkoutComplete,
      completion: completion
    )

    // A poll already in flight is for another checkout (an older pending one, from the
    // foreground or paywall open), so it never redeems this one. Wait it out, then poll this
    // checkout: skipping left the spinner up with nothing left to take it down.
    while outcome == .skippedInFlight, !Task.isCancelled {
      await waitForActiveStripePoll()
      if isRedeemed(contextId) {
        outcome = .redeemed
        break
      }
      outcome = await pollStripeRedemptionResult(
        contextId: contextId,
        productId: productId,
        trigger: .checkoutComplete,
        completion: completion
      )
    }

    if outcome != .redeemed {
      let superwall = self.superwall ?? Superwall.shared
      await MainActor.run {
        superwall.paywallViewController?.updateLoading(.finished)
      }
    }
  }

  func handleStripeCheckoutAbandon(
    contextId: String? = nil,
    productId: String,
    settlingTeleportId: String? = nil
  ) async {
    awaitingCheckoutComplete = false
    settleTeleport(settlingTeleportId, reportedCheckout: contextId)
    let superwall = superwall ?? Superwall.shared
    let product = StoreProduct.blank(productIdentifier: productId)
    let paywallInfo = await MainActor.run { superwall.paywallViewController?.info ?? .empty() }

    let event = InternalSuperwallEvent.Transaction(
      state: .abandon(product),
      paywallInfo: paywallInfo,
      product: product,
      transaction: nil,
      source: .internal,
      isObserved: false,
      storeKitVersion: nil,
      store: .stripe
    )
    await superwall.track(event)
  }

  #endif
  /// Polls for the redemption result of a pending Stripe checkout, if one exists,
  /// decrementing the remaining foreground attempts and clearing state when exhausted.
  func pollPendingStripeCheckoutOnForegroundIfNeeded() async {
    guard let pendingState = pendingStripeCheckoutState else {
      return
    }
    guard pendingState.remainingForegroundAttempts > 0 else {
      clearPendingStripeCheckoutState()
      return
    }

    let outcome = await pollStripeRedemptionResult(
      contextId: pendingState.checkoutContextId,
      productId: pendingState.productId,
      trigger: .foreground,
      completion: pendingState.completion
    )

    // Consume foreground attempts after each trigger completes, except when skipped
    // due to an existing in-flight poll.
    if outcome == .skippedInFlight {
      return
    }

    guard
      let latestState = pendingStripeCheckoutState,
      latestState.checkoutContextId == pendingState.checkoutContextId
    else {
      return
    }

    let updatedState = latestState.consumingForegroundAttempt()
    if updatedState.remainingForegroundAttempts <= 0 {
      clearPendingStripeCheckoutState()
    } else {
      savePendingStripeCheckoutState(updatedState)
    }
  }

  func redeem(
    _ type: RedeemType,
    injectedConfig: Config? = nil
  ) async {
    let superwall = superwall ?? Superwall.shared

    // Only block concurrent .code redemptions if a paywall is currently open
    // (.code is the only type that can dismiss the paywall)
    var shouldCleanupProcessingFlag = false
    if case .code = type {
      // Check isProcessing BEFORE any await to prevent race condition
      if isProcessing {
        return
      }

      #if canImport(WebKit)
      let hasPaywall = await MainActor.run { superwall.paywallViewController != nil }

      if hasPaywall {
        isProcessing = true
        shouldCleanupProcessingFlag = true
      }
      #endif
    }
    defer {
      if shouldCleanupProcessingFlag {
        isProcessing = false
      }
    }

    let latestRedeemResponse = storage.get(LatestRedeemResponse.self)

    let allCodes = await prepareCodesForRedemption(
      type: type,
      existingCodes: latestRedeemResponse?.allCodes ?? [],
      superwall: superwall
    )

    let request = await createRedeemRequest(allCodes: allCodes)
    await trackRedemptionStart(type: type, superwall: superwall)
    await prepareUIForRedemption(type: type, superwall: superwall)

    do {
      // A background redeem changes nothing on the server, so its response is as old as
      // its request. Redeeming a code does, so a fetch sent before the code was redeemed
      // can still read the state before it: that response counts from when it arrives.
      let sentFetch = type.redeemsNewCode ? nil : startEntitlementsFetch()
      let response = try await network.redeemEntitlements(request: request)
      if !type.redeemsNewCode {
        // Saved after the user changed, it would give the new user the old one's entitlements.
        // The user is waiting on a code redemption, so that one always finishes.
        guard
          factory.makeAppUserId() == request.appUserId,
          factory.makeAliasId() == request.aliasId
        else {
          Logger.debug(
            logLevel: .debug,
            scope: .webEntitlements,
            message: "Ignoring redeem response because the user changed during the redeem."
          )
          return
        }
      }
      await handleRedemptionSuccess(
        response: response,
        fetch: sentFetch ?? startEntitlementsFetch(),
        type: type,
        superwall: superwall,
        callbackMode: .legacy
      )
    } catch {
      await handleRedemptionFailure(
        error: error,
        type: type,
        latestRedeemResponse: latestRedeemResponse,
        superwall: superwall
      )
    }
  }

  private func prepareCodesForRedemption(
    type: RedeemType,
    existingCodes: Set<Redeemable>,
    superwall: Superwall
  ) async -> Set<Redeemable> {
    var allCodes = existingCodes

    guard case .code(let code) = type else {
      return allCodes
    }

    let isFirstRedemption = allCodes.isEmpty || !allCodes.contains { $0.code == code }
    let redeemable = Redeemable(code: code, isFirstRedemption: isFirstRedemption)
    allCodes.insert(redeemable)

    #if canImport(WebKit)
    if let paywallVc = superwall.paywallViewController {
      // Mark that redeem called so that we stop the transaction abandon tracking
      await MainActor.run {
        paywallVc.markRedeemInitiated()
      }

      let trackedEvent = await InternalSuperwallEvent.Restore(
        state: .start,
        paywallInfo: paywallVc.info
      )
      await superwall.track(trackedEvent)
    }

    #endif
    return allCodes
  }

  private func createRedeemRequest(allCodes: Set<Redeemable>) async -> RedeemRequest {
    let attributes = storage.get(IntegrationAttributes.self) ?? [:]
    return await RedeemRequest(
      metadata: JSON(attributes),
      deviceId: factory.makeDeviceId(),
      appUserId: factory.makeAppUserId(),
      aliasId: factory.makeAliasId(),
      codes: allCodes,
      receipts: receiptManager.getTransactionReceipts(),
      appTransactionId: ReceiptManager.appTransactionId
    )
  }

  private func trackRedemptionStart(type: RedeemType, superwall: Superwall) async {
    switch type {
    case .code, .existingCodes:
      let startEvent = InternalSuperwallEvent.Redemption(state: .start, type: type)
      await superwall.track(startEvent)
    case .integrationAttributes:
      break
    }
  }

  private func prepareUIForRedemption(type: RedeemType, superwall: Superwall) async {
    guard case .code = type else { return }
    #if canImport(WebKit)
    await MainActor.run {
      superwall.paywallViewController?.updateLoading(.manualLoadingStarted)
      superwall.paywallViewController?.closeSafari()
    }
    #endif
    await delegate.willRedeemLink()
  }

  /// - Parameter fetch: The response's place in the fetch order, from `startEntitlementsFetch()`.
  private func handleRedemptionSuccess(
    response: RedeemResponse,
    fetch: Int,
    type: RedeemType,
    superwall: Superwall,
    callbackMode: RedemptionCallbackMode,
    completion: StripeCheckoutCompletion = .restore,
    checkoutContextId: String? = nil
  ) async {
    var response = response
    #if canImport(WebKit)
    let previousWebEntitlements = Set(
      storage.get(LatestRedeemResponse.self)?.customerInfo.entitlements ?? []
    )
    #endif
    // A later fetch has already saved newer customer info. The codes' results are still this
    // response's, but its customer info is out of date. Saved before anything suspends, so a
    // fetch finishing meanwhile can't be overwritten.
    if fetch < lastSavedEntitlementsFetch,
      let latestCustomerInfo = storage.get(LatestRedeemResponse.self)?.customerInfo {
      response.customerInfo = latestCustomerInfo
    } else {
      storage.save(Date(), forType: LastWebEntitlementsFetchDate.self)
    }
    storage.save(response, forType: LatestRedeemResponse.self)
    lastSavedEntitlementsFetch = max(lastSavedEntitlementsFetch, fetch)

    switch type {
    case .code, .existingCodes:
      let completeEvent = InternalSuperwallEvent.Redemption(state: .complete, type: type)
      await superwall.track(completeEvent)
    case .integrationAttributes:
      break
    }

    let (allEntitlements, paywallEntitlementIds) = await processEntitlements(
      response: response,
      type: type,
      completion: completion,
      superwall: superwall
    )

    // A newer fetch may have saved its customer info while this one was being processed.
    let latestWebCustomerInfo =
      storage.get(LatestRedeemResponse.self)?.customerInfo ?? response.customerInfo
    await mergeAndApplyCustomerInfo(
      webCustomerInfo: latestWebCustomerInfo,
      superwall: superwall
    )

    await updateSubscriptionStatus(
      with: mergedEntitlements(webCustomerInfo: latestWebCustomerInfo),
      superwall: superwall
    )

    #if canImport(WebKit)
    // A paywall let through before the code was redeemed, and still on its way, closes as
    // restored when it opens. Recorded even when a paywall is on screen now: it may have
    // appeared after the redemption looked for one, so nothing finished it. One that the
    // redemption did finish is closing, and the check on open leaves it alone.
    if case .code = type,
      let arrival = WebEntitlementsArrival(
        previousWebEntitlements: previousWebEntitlements,
        webEntitlements: Set(latestWebCustomerInfo.entitlements)
      ) {
      recordArrival(arrival)
    }
    #endif

    if case .code(let code) = type {
      await handleCodeRedemptionCompletion(
        code: code,
        response: response,
        allEntitlementIds: Set(allEntitlements.map { $0.id }),
        paywallEntitlementIds: paywallEntitlementIds,
        superwall: superwall,
        callbackMode: callbackMode,
        completion: completion,
        checkoutContextId: checkoutContextId
      )
    }
  }

  private func processEntitlements(
    response: RedeemResponse,
    type: RedeemType,
    completion: StripeCheckoutCompletion,
    superwall: Superwall
  ) async -> (allEntitlements: Set<Entitlement>, paywallEntitlementIds: Set<String>) {
    let allEntitlements = mergedEntitlements(webCustomerInfo: response.customerInfo)

    var paywallEntitlementIds: Set<String> = []

    // A restore is only complete once every entitlement the paywall offers is active, and the
    // paywall hears restore_complete or restore_fail. A purchase bought one product, so none of
    // that applies: it hears transaction_complete instead.
    #if canImport(WebKit)
    if case .code = type, completion == .restore, let paywallVc = superwall.paywallViewController {
      for id in await paywallVc.info.productIds {
        let entitlements = superwall.entitlements.byProductId(id)
        paywallEntitlementIds.formUnion(entitlements.map { $0.id })
      }

      let allEntitlementIds = Set(allEntitlements.map { $0.id })
      // Need to check that entitlements aren't empty because if they are then
      // it can't be claimed that you've restored the entitlements.
      if !paywallEntitlementIds.isEmpty {
        if paywallEntitlementIds.subtracting(allEntitlementIds).isEmpty {
          let trackedEvent = await InternalSuperwallEvent.Restore(
            state: .complete,
            paywallInfo: paywallVc.info
          )
          await superwall.track(trackedEvent)
          await paywallVc.webView.messageHandler.handle(.restoreComplete)
        } else {
          await trackRestorationFailure(
            paywallViewController: paywallVc,
            message: "Failed to restore subscriptions from the web",
            superwall: superwall
          )
        }
      }
    }

    #endif
    return (allEntitlements, paywallEntitlementIds)
  }

  /// The device's active entitlements merged with `webCustomerInfo`'s.
  private func mergedEntitlements(webCustomerInfo: CustomerInfo) -> Set<Entitlement> {
    let deviceCustomerInfo = storage.get(LatestDeviceCustomerInfo.self) ?? .blank()
    let activeDeviceEntitlements = Set(deviceCustomerInfo.entitlements.filter { $0.isActive })
    let combinedEntitlements =
      Array(activeDeviceEntitlements) + Array(webCustomerInfo.entitlements)
    return Entitlement.mergePrioritized(combinedEntitlements)
  }

  /// Merges device and web entitlements into a single `CustomerInfo`, applying
  /// external purchase controller logic when needed, and assigns it to
  /// `superwall.customerInfo`.
  private func mergeAndApplyCustomerInfo(
    webCustomerInfo: CustomerInfo,
    superwall: Superwall
  ) async {
    let mergedCustomerInfo: CustomerInfo
    if factory.makeHasExternalPurchaseController() {
      let subscriptionStatus = await MainActor.run { superwall.subscriptionStatus }
      mergedCustomerInfo = CustomerInfo.forExternalPurchaseController(
        storage: storage,
        subscriptionStatus: subscriptionStatus,
        granted: entitlementsInfo.granted
      )
    } else {
      let deviceCustomerInfo = storage.get(LatestDeviceCustomerInfo.self) ?? .blank()
      mergedCustomerInfo = deviceCustomerInfo.merging(
        with: webCustomerInfo,
        granting: entitlementsInfo.granted
      )
    }

    await MainActor.run {
      if superwall.customerInfo != mergedCustomerInfo {
        superwall.customerInfo = mergedCustomerInfo
      }
    }
  }

  private func updateSubscriptionStatus(
    with allEntitlements: Set<Entitlement>,
    superwall: Superwall
  ) async {
    let activeEntitlements = allEntitlements.filter { $0.isActive }
    let status: SubscriptionStatus =
      activeEntitlements.isEmpty ? .inactive : .active(activeEntitlements)
    await superwall.internallySetSubscriptionStatus(to: status, superwall: superwall)
  }

  private func handleCodeRedemptionCompletion(
    code: String,
    response: RedeemResponse,
    allEntitlementIds: Set<String>,
    paywallEntitlementIds: Set<String>,
    superwall: Superwall,
    callbackMode: RedemptionCallbackMode,
    completion: StripeCheckoutCompletion,
    checkoutContextId: String?
  ) async {
    guard let codeResult = response.results.first(where: { $0.code == code }) else { return }

    let superwallOptions = factory.makeSuperwallOptions()
    #if canImport(WebKit)
    let showConfirmation = superwallOptions.paywalls.shouldShowWebPurchaseConfirmationAlert
    #endif

    func afterRedeem() async {
      if callbackMode == .pollFakeCompatibility {
        await self.delegate.willRedeemLink()
        try? await Task.sleep(nanoseconds: 200_000_000)
        await self.delegate.didRedeemLink(result: codeResult)
      }

      #if canImport(WebKit)
      // Track free trial start and schedule notification if applicable
      if case .success(_, let redemptionInfo) = codeResult,
        let redemptionProduct = redemptionInfo.paywallInfo?.product,
        redemptionProduct.trialPeriodDays > 0,
        let paywallVc = superwall.paywallViewController {
        let paywallInfo = await paywallVc.info
        if paywallInfo.isFreeTrialAvailable {
          let product = StoreProduct.blank(
            productIdentifier: redemptionProduct.identifier
          )
          await superwall.track(
            InternalSuperwallEvent.FreeTrialStart(
              paywallInfo: paywallInfo,
              product: product,
              transaction: nil
            )
          )
          let notifications = paywallInfo.localNotifications.filter {
            $0.type == .trialStarted
          }
          await self.notificationScheduler.scheduleNotifications(
            notifications,
            fromPaywallId: paywallInfo.identifier,
            factory: self.factory
          )
        }
      }

      #endif
      switch completion {
      case .restore:
        #if canImport(WebKit)
        if let paywallVc = superwall.paywallViewController,
          !paywallEntitlementIds.isEmpty,
          paywallEntitlementIds.subtracting(allEntitlementIds).isEmpty,
          superwallOptions.paywalls.automaticallyDismiss {
          await superwall.dismiss(paywallVc, result: .restored)
        }
        #endif
      case let .purchase(productId, shouldDismiss):
        #if canImport(WebKit)
        if case .success(_, let redemptionInfo) = codeResult,
          let paywallVc = superwall.paywallViewController {
          await finishWebPurchase(
            productId: productId,
            trialPeriodDays: redemptionInfo.paywallInfo?.product?.trialPeriodDays ?? 0,
            shouldDismiss: shouldDismiss && superwallOptions.paywalls.automaticallyDismiss,
            paywallViewController: paywallVc,
            superwall: superwall
          )
        }
        #endif
      }

      #if canImport(WebKit)
      await MainActor.run {
        superwall.paywallViewController?.updateLoading(.finished)
      }

      #endif
      if callbackMode == .legacy {
        await self.delegate.didRedeemLink(result: codeResult)
      }
    }

    #if canImport(WebKit)
    if showConfirmation {
      let title = LocalizationLogic.localizedBundle().localizedString(
        forKey: "purchase_success_title",
        value: nil,
        table: nil
      )
      let message = LocalizationLogic.localizedBundle().localizedString(
        forKey: "purchase_success_message",
        value: nil,
        table: nil
      )
      let closeActionTitle = LocalizationLogic.localizedBundle().localizedString(
        forKey: "purchase_success_action_title",
        value: nil,
        table: nil
      )

      if let paywallVc = await MainActor.run(body: { superwall.paywallViewController }) {
        await paywallVc.presentAlert(
          title: title,
          message: message,
          closeActionTitle: closeActionTitle,
          onClose: { [weak self] in
            Task {
              await afterRedeem()
              await self?.clearPendingStripeCheckoutState(for: checkoutContextId)
            }
          }
        )
      } else {
        await presentAlertOnTopViewController(
          title: title,
          message: message,
          closeActionTitle: closeActionTitle,
          onClose: { [weak self] in
            Task {
              await afterRedeem()
              await self?.clearPendingStripeCheckoutState(for: checkoutContextId)
            }
          }
        )
      }
    } else {
      await afterRedeem()
      clearPendingStripeCheckoutState(for: checkoutContextId)
    }
    #else
    // There's no SDK alert UI here, so the redemption finishes without one.
    await afterRedeem()
    clearPendingStripeCheckoutState(for: checkoutContextId)
    #endif
  }

  #if canImport(WebKit)
  /// Finishes a redeemed web purchase the way `TransactionManager` finishes
  /// an App Store purchase made from a paywall.
  private func finishWebPurchase(
    productId: String,
    trialPeriodDays: Int,
    shouldDismiss: Bool,
    paywallViewController: PaywallViewController,
    superwall: Superwall
  ) async {
    let product = StoreProduct.blank(productIdentifier: productId)
    let paywallInfo = await paywallViewController.info
    let didStartFreeTrial = trialPeriodDays > 0 && paywallInfo.isFreeTrialAvailable
    let trialEndDate = didStartFreeTrial
      ? Calendar.current.date(byAdding: .day, value: trialPeriodDays, to: Date())
      : nil

    await paywallViewController.markPurchaseCompleted(product)
    await paywallViewController.webView.messageHandler.handle(
      .transactionComplete(
        trialEndDate: trialEndDate,
        productIdentifier: productId,
        didStartFreeTrial: didStartFreeTrial
      )
    )

    if shouldDismiss {
      await superwall.dismiss(paywallViewController, result: .purchased(product))
    }
  }

  @MainActor
  private func presentAlertOnTopViewController(
    title: String,
    message: String,
    closeActionTitle: String,
    onClose: (() -> Void)?
  ) {
    guard let topVc = PlatformViewController.topMostViewController else {
      onClose?()
      return
    }
    #if os(macOS)
    // A window shows one sheet at a time.
    guard topVc.view.window?.attachedSheet == nil else {
      onClose?()
      return
    }
    AlertControllerFactory.present(
      title: title,
      message: message,
      closeActionTitle: closeActionTitle,
      onClose: onClose,
      on: topVc
    )
    #else
    guard topVc.presentedViewController == nil else {
      onClose?()
      return
    }
    let alertController = AlertControllerFactory.make(
      title: title,
      message: message,
      closeActionTitle: closeActionTitle,
      onClose: onClose,
      sourceView: topVc.view
    )
    topVc.present(alertController, animated: true)
    #endif
  }

  #endif
  private func handleRedemptionFailure(
    error: Error,
    type: RedeemType,
    latestRedeemResponse: RedeemResponse?,
    superwall: Superwall
  ) async {
    switch type {
    case .code, .existingCodes:
      let event = InternalSuperwallEvent.Redemption(state: .fail, type: type)
      await superwall.track(event)
    case .integrationAttributes:
      break
    }

    if case .code(let code) = type {
      #if canImport(WebKit)
      if let paywallVc = superwall.paywallViewController {
        await trackRestorationFailure(
          paywallViewController: paywallVc,
          message: error.localizedDescription,
          superwall: superwall
        )
      }

      #endif
      let errorResult = RedemptionResult.error(
        code: code,
        error: RedemptionResult.ErrorInfo(message: error.localizedDescription)
      )

      #if canImport(WebKit)
      await MainActor.run {
        superwall.paywallViewController?.updateLoading(.finished)
      }
      #endif
      await delegate.didRedeemLink(result: errorResult)
    }

    Logger.debug(
      logLevel: .error,
      scope: .webEntitlements,
      message: "Failed to redeem",
      info: [:]
    )
  }

  #if canImport(WebKit)
  private func trackRestorationFailure(
    paywallViewController: PaywallViewController,
    message: String,
    superwall: Superwall
  ) async {
    let trackedEvent = await InternalSuperwallEvent.Restore(
      state: .fail(message),
      paywallInfo: paywallViewController.info
    )
    await superwall.track(trackedEvent)
    await paywallViewController.webView.messageHandler.handle(.restoreFail(message))
    await paywallViewController.presentAlert(
      title: superwall.options.paywalls.restoreFailed.title,
      message: superwall.options.paywalls.restoreFailed.message,
      closeActionTitle: superwall.options.paywalls.restoreFailed.closeButtonTitle
    )
  }
  #endif

  private var pendingStripeCheckoutState: PendingStripeCheckoutPollState? {
    storage.get(PendingStripeCheckoutPollStorage.self)
  }

  private func savePendingStripeCheckoutState(_ state: PendingStripeCheckoutPollState) {
    storage.save(state, forType: PendingStripeCheckoutPollStorage.self)
  }

  private func clearPendingStripeCheckoutState() {
    storage.delete(PendingStripeCheckoutPollStorage.self)
  }

  /// Clears the pending checkout only if it's this checkout's, so a poll that finishes an older
  /// checkout leaves a newer one to be recovered. Nil clears whatever is pending.
  private func clearPendingStripeCheckoutState(for checkoutContextId: String?) {
    if let checkoutContextId,
      pendingStripeCheckoutState?.checkoutContextId != checkoutContextId {
      return
    }
    clearPendingStripeCheckoutState()
  }

  private func makePollRedemptionRequest(
    contextId: String
  ) -> PollRedemptionResultRequest {
    return PollRedemptionResultRequest(
      checkoutContextId: contextId,
      deviceId: factory.makeDeviceId(),
      appUserId: factory.makeAppUserId()
    )
  }

  private func pollStripeRedemptionResult(
    contextId: String,
    productId: String,
    trigger: StripePollTrigger,
    completion: StripeCheckoutCompletion = .restore
  ) async -> StripePollOutcome {
    if hasActiveStripePoll {
      return .skippedInFlight
    }

    hasActiveStripePoll = true
    var finalOutcome: StripePollOutcome = .noRedemptionFound
    defer {
      hasActiveStripePoll = false
      lastCompletedStripePollResult = (contextId: contextId, outcome: finalOutcome)
    }

    let request = makePollRedemptionRequest(contextId: contextId)
    let startedAt = DispatchTime.now().uptimeNanoseconds

    while !Task.isCancelled {
      if let state = pendingStripeCheckoutState,
        state.checkoutContextId == contextId,
        hasStripePendingTimedOut(state) {
        clearPendingStripeCheckoutState()
        return .noRedemptionFound
      }
      // A newer checkout was reported complete: this one stops so that one is polled. One that
      // was only started doesn't stop it, since this one may still be paid for.
      if let completingCheckoutContextId, completingCheckoutContextId != contextId {
        return .noRedemptionFound
      }

      do {
        let response = try await network.pollRedemptionResult(request: request)

        if let code = response.results.first?.code {
          let superwall = superwall ?? Superwall.shared
          clearTeleport(paidFor: contextId)
          // The link or the page may have said how to finish since this poll started.
          var completion = completion
          if let state = pendingStripeCheckoutState, state.checkoutContextId == contextId {
            completion = state.completion
          }
          // Redeeming the checkout's code changed the user's entitlements, so this response
          // is newer than any fetch already in flight.
          await handleRedemptionSuccess(
            response: response,
            fetch: startEntitlementsFetch(),
            type: .code(code),
            superwall: superwall,
            callbackMode: .pollFakeCompatibility,
            completion: completion,
            checkoutContextId: contextId
          )
          finalOutcome = .redeemed
          return finalOutcome
        }

        switch response.status {
        case .failed:
          clearPendingStripeCheckoutState(for: contextId)
          clearTeleport(paidFor: contextId)
          finalOutcome = .checkoutFailed
          return finalOutcome
        case .pending:
          let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
          if elapsed >= stripePendingPollTimeoutNs {
            finalOutcome = .noRedemptionFound
            return finalOutcome
          }
          try? await Task.sleep(nanoseconds: stripePendingPollIntervalNs)
          continue
        case .complete:
          clearPendingStripeCheckoutState(for: contextId)
          clearTeleport(paidFor: contextId)
          finalOutcome = .noRedemptionFound
          return finalOutcome
        case .none:
          finalOutcome = .noRedemptionFound
          return finalOutcome
        }
      } catch {
        Logger.debug(
          logLevel: .warn,
          scope: .webEntitlements,
          message: "Stripe poll-redemption-result request failed",
          error: error
        )
        finalOutcome = .requestFailed
        return finalOutcome
      }
    }
    finalOutcome = .noRedemptionFound
    return finalOutcome
  }

  @objc
  nonisolated private func handleAppForeground() {
    Task {
      await self.handleForegroundPolling()
    }
  }

  /// Called on foreground. Polls for pending Stripe checkout redemption (showing a
  /// loading spinner on the paywall if needed) and then refreshes web entitlements.
  private func handleForegroundPolling() async {
    guard factory.makeIsContainerReady() else { return }
    #if canImport(WebKit)
    let superwall = superwall ?? Superwall.shared
    let hasVisiblePaywall = await MainActor.run { superwall.paywallViewController != nil }

    // If the checkout sheet is still open inside the paywall (checkout_submit
    // fired but checkout_complete hasn't yet), skip the foreground stripe poll.
    // checkout_complete will show the spinner and start polling when the sheet
    // closes.
    if hasVisiblePaywall, awaitingCheckoutComplete {
      await pollWebEntitlements()
      return
    }
    #endif

    // A teleport read paid polls its checkout itself, so the pending one isn't polled twice.
    if await !recoverPendingTeleport(onForeground: true) {
      await pollPendingStripeCheckoutShowingLoading()
    }
    await pollWebEntitlements()
  }

  /// Polls the pending Stripe checkout, if there is one, with the spinner on the visible
  /// paywall while it does.
  private func pollPendingStripeCheckoutShowingLoading() async {
    #if !canImport(WebKit)
    await pollPendingStripeCheckoutOnForegroundIfNeeded()
    #else
    let superwall = superwall ?? Superwall.shared
    let hasVisiblePaywall = await MainActor.run { superwall.paywallViewController != nil }
    let shouldShowLoading = hasVisiblePaywall && shouldShowStripeRecoveryLoadingOnPaywallOpen()

    if shouldShowLoading {
      await MainActor.run {
        superwall.paywallViewController?.updateLoading(.manualLoadingStarted)
      }
    }

    await pollPendingStripeCheckoutOnForegroundIfNeeded()

    if shouldShowLoading {
      await MainActor.run {
        superwall.paywallViewController?.updateLoading(.manualLoadingEnded)
      }
    }
    #endif
  }

  /// A return link says the checkout was paid for. Keeps it pending, like a submitted
  /// checkout, so it's redeemed even when the paywall that started it is gone: a paywall
  /// opened meanwhile waits behind the spinner, and later launches and foregrounds poll again.
  /// Being paid, it's kept for longer than a checkout that was only submitted.
  func handlePurchasedReturn(_ purchase: PurchasedReturn) async {
    let contextId = purchase.checkoutContextId
    // On a warm return the paywall page may have reported it first and redeemed it already.
    if isRedeemed(contextId) {
      return
    }
    // The page that opened the teleport is still on screen. It reports the purchase itself and
    // says how to finish it, which this link doesn't, so it gets a moment to.
    if purchase.completion == .restore, await isStoredTeleportWithItsPage() {
      await waitForPageReport(of: contextId)
      if isRedeemed(contextId) {
        return
      }
    }
    let fromTeleport = await teleportPurchase(for: purchase)
    savePaidCheckout(purchase, fromTeleport: fromTeleport)

    // An older checkout's poll stops for this one, as it does for one the page reports
    // complete, so this one doesn't wait behind a poll that can't redeem it.
    completingCheckoutContextId = contextId
    defer {
      if completingCheckoutContextId == contextId {
        completingCheckoutContextId = nil
      }
    }

    // A poll in flight may be this checkout's, started by the page. Let it finish rather than
    // take its spinner down.
    if hasActiveStripePoll {
      await waitForActiveStripePoll()
      if isRedeemed(contextId) || hasActiveStripePoll {
        return
      }
    }
    guard pendingStripeCheckoutState?.checkoutContextId == contextId else {
      return
    }
    await pollPendingStripeCheckoutShowingLoading()
  }

  /// Keeps a checkout something said was paid for as the pending one.
  private func savePaidCheckout(_ purchase: PurchasedReturn, fromTeleport: PurchasedReturn?) {
    let contextId = purchase.checkoutContextId
    if let existing = pendingStripeCheckoutState, existing.checkoutContextId == contextId {
      // Already pending, as after an embedded submit, which can't say how to finish. A link that
      // says so wins; one that doesn't keeps what's stored, as does one that names no product.
      // It's saved again either way, keeping the attempts left: the link says it's paid, so the
      // time it has to be redeemed starts over.
      var completion = existing.completion
      if purchase.completion != .restore {
        completion = purchase.completion
      } else if existing.completion == .restore, let fromTeleport {
        completion = fromTeleport.completion
      }
      var productId = purchase.productId
      if productId.isEmpty {
        productId = existing.productId
      }
      if productId.isEmpty, let fromTeleport {
        productId = fromTeleport.productId
      }
      savePendingStripeCheckoutState(
        .init(
          checkoutContextId: contextId,
          productId: productId,
          completion: completion,
          isPaid: true,
          remainingForegroundAttempts: existing.remainingForegroundAttempts
        )
      )
    } else {
      let finished = fromTeleport ?? purchase
      savePendingStripeCheckoutState(
        .init(
          checkoutContextId: contextId,
          productId: finished.productId,
          completion: finished.completion,
          isPaid: true
        )
      )
    }
  }

  /// How the teleport left open finishes this purchase, when the link doesn't say how to. Only
  /// a link for the checkout that teleport started borrows how it finishes, so both finish it the
  /// same way whichever is handled first. A link for any other checkout, such as an older one
  /// that came back late, keeps its own restore. When the teleport's checkout isn't known yet,
  /// it's read once; a failed read borrows nothing.
  private func teleportPurchase(for purchase: PurchasedReturn) async -> PurchasedReturn? {
    guard
      purchase.completion == .restore,
      let teleport = storage.get(PendingTeleportStorage.self),
      !teleport.hasExpired()
    else {
      return nil
    }
    var checkoutContextId = teleport.checkoutContextId
    if checkoutContextId == nil,
      let status = try? await network.getTeleportStatus(teleportId: teleport.teleportId) {
      checkoutContextId = status.checkoutContextId.flatMap { $0.isEmpty ? nil : $0 }
      rememberCheckout(checkoutContextId, startedBy: teleport)
    }
    guard checkoutContextId == purchase.checkoutContextId else {
      return nil
    }
    return teleport.purchase(
      checkoutContextId: purchase.checkoutContextId,
      productId: purchase.productId
    )
  }

  /// Keeps the checkout a status read says the stored teleport started, while it's still the
  /// one stored.
  private func rememberCheckout(_ checkoutContextId: String?, startedBy teleport: PendingTeleportState) {
    guard
      let checkoutContextId,
      let stored = storage.get(PendingTeleportStorage.self),
      stored.teleportId == teleport.teleportId,
      stored.checkoutContextId != checkoutContextId
    else {
      return
    }
    storage.save(stored.startedCheckout(checkoutContextId), forType: PendingTeleportStorage.self)
  }

  /// Waits for the paywall page to report the checkout, while its teleport is still the page's
  /// to finish, for up to `pageReportWaitNs`.
  private func waitForPageReport(of contextId: String) async {
    let waitStart = DispatchTime.now().uptimeNanoseconds
    while !Task.isCancelled {
      if isRedeemed(contextId) || completingCheckoutContextId == contextId {
        return
      }
      if await !isStoredTeleportWithItsPage() {
        return
      }
      if DispatchTime.now().uptimeNanoseconds - waitStart >= pageReportWaitNs {
        return
      }
      try? await Task.sleep(nanoseconds: 50_000_000)
    }
  }

  private func hasStripePendingTimedOut(_ state: PendingStripeCheckoutPollState) -> Bool {
    let elapsed = Date().timeIntervalSince(state.updatedAt)
    // A checkout known to be paid outlives a poll that fails or is cut short.
    if state.isPaid {
      return elapsed >= PendingStripeCheckoutPollState.paidTimeLimit
    }
    let timeoutSeconds = TimeInterval(stripePendingPollTimeoutNs) / 1_000_000_000
    return elapsed >= timeoutSeconds
  }

  /// How long entitlements fetched by ``pollWebEntitlements(config:isFirstTime:)``
  /// stay fresh when the app has no web2app config to set `entitlementsMaxAge`.
  ///
  /// Every app polls, because purchases reported by a server, such as custom
  /// store purchases, refunds and renewals, only reach the device through this
  /// fetch. A shorter age surfaces a revocation, or a renewal past the cached
  /// expiry, sooner, but adds a request to more foregrounds on every install.
  /// 15 minutes bounds that to at most four requests an hour per active user,
  /// while a change still shows up within a typical session. The fetch on
  /// launch ignores it.
  static let defaultEntitlementsMaxAge: Seconds = 15 * 60

  /// Fetches entitlements from the server, unless they were fetched within
  /// `entitlementsMaxAge`, or ``defaultEntitlementsMaxAge`` when the app has
  /// no web2app config. The first poll after launch always fetches. Skipped in
  /// test mode. Any other poll joins one that's already in flight.
  func pollWebEntitlements(
    config: Config? = nil,
    isFirstTime: Bool = false
  ) async {
    if factory.makeTestModeManager().isTestMode {
      return
    }

    if !isFirstTime,
      let inFlightPoll = inFlightWebEntitlementsPoll {
      await inFlightPoll.value
      return
    }

    if !isFirstTime,
      let lastFetchedWebEntitlementsAt = storage.get(LastWebEntitlementsFetchDate.self) {
      let entitlementsMaxAge = config?.web2appConfig?.entitlementsMaxAge
        ?? factory.makeEntitlementsMaxAge()
        ?? Self.defaultEntitlementsMaxAge
      let timeElapsed = Date().timeIntervalSince(lastFetchedWebEntitlementsAt)
      guard timeElapsed > entitlementsMaxAge else {
        return
      }
    }

    let poll = Task {
      _ = await self.refreshWebEntitlements(dismissesCoveredPaywall: true)
    }
    inFlightWebEntitlementsPoll = poll
    await poll.value
    if inFlightWebEntitlementsPoll == poll {
      inFlightWebEntitlementsPoll = nil
    }
  }

  /// The next place in the order of responses that carry entitlements.
  private func startEntitlementsFetch() -> Int {
    entitlementsFetchCount += 1
    return entitlementsFetchCount
  }

  func redeemAfterPurchase() async {
    await redeem(.existingCodes)
  }

  /// Fetches entitlements from the server now, ignoring `entitlementsMaxAge`
  /// and whether the app has a web2app config.
  ///
  /// Custom store purchases are reported to Superwall by the developer's
  /// server, so their entitlements come from this fetch even in apps that
  /// don't sell on the web.
  ///
  /// - Parameter dismissesCoveredPaywall: Whether newly active entitlements
  ///   that cover the presented paywall's products count as a restore, which
  ///   tracks it and dismisses the paywall. Only the poll does this, for users
  ///   coming back from a web checkout, and never while a purchase is in
  ///   progress. After an in-app or custom store purchase it would turn the
  ///   purchase into a restore and close a paywall the developer kept open.
  /// - Returns: The latest customer info, or `nil` if the fetch failed or
  ///   its response was ignored. When a newer fetch's response was saved
  ///   first, that newer customer info.
  @discardableResult
  func refreshWebEntitlements(dismissesCoveredPaywall: Bool = false) async -> CustomerInfo? {
    let fetch = startEntitlementsFetch()
    let appUserId = factory.makeAppUserId()
    do {
      let response = try await network.getEntitlements(
        appUserId: appUserId,
        deviceId: factory.makeDeviceId()
      )

      if factory.makeAppUserId() != appUserId {
        Logger.debug(
          logLevel: .debug,
          scope: .webEntitlements,
          message: "Ignoring web entitlements response because the user changed during the fetch."
        )
        return nil
      }

      // Fetches can overlap and finish in any order. Once a newer fetch has
      // saved its response, this one is out of date and must not replace it.
      if fetch < lastSavedEntitlementsFetch {
        return storage.get(LatestRedeemResponse.self)?.customerInfo
      }

      // Read the cached entitlements after the fetch, not before it. Refreshes
      // can overlap, and from here to the save below nothing suspends, so only
      // the first response to arrive sees the change and acts on it.
      let existingWebEntitlements = Set(
        storage.get(LatestRedeemResponse.self)?.customerInfo.entitlements ?? [])

      // A response with zero entitlements must not replace cached web
      // entitlements that are still within their expiry date. The server
      // reports a revocation by returning the entitlement as inactive —
      // and it enumerates every config-mapped entitlement even for users
      // with no purchases — so a fully empty array is a backend or config
      // artifact (alias mismatch, failed upstream lookup), not a
      // revocation. Real revocations arrive non-empty and apply
      // immediately through the save below. If an empty response replaced
      // the cache, the next cold launch would read the user as inactive
      // until a network poll recovered them. Entitlements with no expiry
      // date are not protected by this guard. We skip saving the fetch
      // date so the next poll retries without waiting out
      // `entitlementsMaxAge`.
      let hasUnexpiredWebEntitlements = existingWebEntitlements.contains {
        $0.isActive && ($0.expiresAt ?? .distantPast) > Date()
      }
      if response.customerInfo.entitlements.isEmpty && hasUnexpiredWebEntitlements {
        Logger.debug(
          logLevel: .warn,
          scope: .webEntitlements,
          message: "Ignoring empty web entitlements response because unexpired web entitlements are cached."
        )
        return nil
      }

      // Update the latest redeem response with the entitlements and customer info from the response.
      if var latestRedeemResponse = storage.get(LatestRedeemResponse.self) {
        latestRedeemResponse.customerInfo = response.customerInfo
        storage.save(latestRedeemResponse, forType: LatestRedeemResponse.self)
      } else {
        // Create new redeem response with empty results. This is to make sure web entitlements
        // are added correctly when setting the subscription status on load.
        let latestRedeemResponse = RedeemResponse(
          results: [],
          customerInfo: response.customerInfo
        )
        storage.save(latestRedeemResponse, forType: LatestRedeemResponse.self)
      }

      storage.save(Date(), forType: LastWebEntitlementsFetchDate.self)
      lastSavedEntitlementsFetch = fetch

      // Use the injected superwall instance or fall back to shared
      let superwall = superwall ?? (Superwall.isInitialized ? Superwall.shared : nil)
      guard let superwall = superwall else {
        return response.customerInfo
      }

      // Apply the customer info even when the entitlements haven't changed,
      // so new subscriptions and non-subscriptions reach `customerInfo`.
      await mergeAndApplyCustomerInfo(
        webCustomerInfo: response.customerInfo,
        superwall: superwall
      )

      let webEntitlements = Set(response.customerInfo.entitlements)
      if existingWebEntitlements != webEntitlements {
        // Derive the status from device + web only, as the redeem path does.
        // The merged customer info also carries granted entitlements, which
        // are applied when the status publishes and must never enter the
        // assigned status — or clearing them could never revoke them.
        let deviceCustomerInfo = storage.get(LatestDeviceCustomerInfo.self) ?? .blank()
        let activeDeviceEntitlements = Set(deviceCustomerInfo.entitlements.filter { $0.isActive })
        let deviceAndWebEntitlements = activeDeviceEntitlements.union(
          Set(response.customerInfo.entitlements)
        )
        let activeEntitlements = deviceAndWebEntitlements.filter { $0.isActive }
        await updateSubscriptionStatus(with: deviceAndWebEntitlements, superwall: superwall)

        // Timed once the status has them: an audience evaluated before then didn't see them.
        if dismissesCoveredPaywall,
          let arrival = WebEntitlementsArrival(
            previousWebEntitlements: existingWebEntitlements,
            webEntitlements: webEntitlements
          ) {
          recordArrival(arrival)
        }

        #if canImport(WebKit)
        // If there's a paywall, check if we should dismiss it
        // A purchase in progress, such as one in a custom store's checkout,
        // reports its own result, so its entitlements aren't a restore.
        if dismissesCoveredPaywall,
          factory.makePurchasingCoordinator().purchase == nil,
          let paywallVc = superwall.paywallViewController {
          let (presentationId, keepsItsResult) = await MainActor.run {
            (Self.presentedPresentationId(of: paywallVc), Self.isClosingAsPaid(paywallVc))
          }
          // A paywall closing as purchased or restored keeps its result. One the user declined
          // can still be up, as when the app that shows it left it there, and is restored.
          if !keepsItsResult {
            await dismissIfCovered(
              paywallVc,
              activeEntitlementIds: Set(activeEntitlements.map { $0.id }),
              presentationId: presentationId,
              superwall: superwall
            )
          }
        }
        #endif
      }
      return response.customerInfo
    } catch {
      Logger.debug(
        logLevel: .warn,
        scope: .webEntitlements,
        message: "Polling web entitlements failed",
        error: error
      )
      return nil
    }
  }

  /// Remembers which web entitlements just became active, and when.
  private func recordArrival(_ arrival: WebEntitlementsArrival) {
    webEntitlementsArrivals.append(arrival)
    if webEntitlementsArrivals.count > Self.keptArrivals {
      webEntitlementsArrivals.removeFirst(webEntitlementsArrivals.count - Self.keptArrivals)
    }
  }

  #if canImport(WebKit)
  /// Called when a paywall opens. Closes it as restored when web entitlements that cover its
  /// products arrived after its audience was evaluated: it was let through while they were
  /// still on their way, as at launch, when presentation doesn't wait for the first fetch.
  /// A paywall whose audience already saw them active was shown to a subscribed user on
  /// purpose, such as an upgrade offer, and stays.
  ///
  /// - Returns: Whether the paywall was found covered and closed.
  @discardableResult
  func dismissPaywallCoveredWhileLoading(_ paywallVc: PaywallViewController) async -> Bool {
    guard !webEntitlementsArrivals.isEmpty else {
      return false
    }
    let (request, presentationId) = await MainActor.run {
      (paywallVc.request, Self.presentedPresentationId(of: paywallVc))
    }
    // A paywall already closing, such as one a recovered checkout just finished, is done.
    guard let presentationId else {
      return false
    }
    // A paywall with no placement, such as one the debugger opens, never counts.
    let evaluatedAt = request?.presentationInfo.placementData == nil
      ? nil
      : request?.audienceEvaluatedAt
    // Only entitlements that arrived after its audience was evaluated count, and only ones the
    // audience didn't already see active from elsewhere, such as the App Store: a paywall
    // shown anyway, such as an upgrade offer, stays.
    let arrivedSinceEvaluation = webEntitlementsArrivals
      .filter { $0.cameAfter(evaluatedAt) }
      .reduce(into: Set<String>()) { $0.formUnion($1.newlyActiveIds) }
      .subtracting(request?.entitlementIdsSeenByAudience ?? [])
    guard !arrivedSinceEvaluation.isEmpty else {
      return false
    }
    guard factory.makePurchasingCoordinator().purchase == nil else {
      return false
    }
    let superwall = superwall ?? (Superwall.isInitialized ? Superwall.shared : nil)
    guard let superwall = superwall else {
      return false
    }
    return await dismissIfCovered(
      paywallVc,
      activeEntitlementIds: Set(superwall.entitlements.active.map { $0.id }),
      newlyCoveredBy: arrivedSinceEvaluation,
      presentationId: presentationId,
      superwall: superwall
    )
  }

  /// The id of the paywall's presentation once it's fully on screen with nothing closing it
  /// yet, or `nil`.
  @MainActor
  private static func presentedPresentationId(of paywallVc: PaywallViewController) -> UUID? {
    paywallVc.store.read { state in
      if case .presented(let presentation) = state.phase,
        presentation.dismissal == nil {
        return presentation.id
      }
      return nil
    }
  }

  /// Whether the paywall's presentation was dismissed as purchased or restored.
  @MainActor
  private static func isClosingAsPaid(_ paywallVc: PaywallViewController) -> Bool {
    paywallVc.store.read { state in
      guard let result = state.latestPresentation?.dismissal?.result else {
        return false
      }
      if case .declined = result {
        return false
      }
      return true
    }
  }

  /// Tracks a restore and dismisses the paywall when the active entitlements cover every
  /// entitlement its products unlock.
  ///
  /// - Parameters:
  ///   - newlyCoveredBy: When set, at least one of these entitlements must be one the paywall
  ///     unlocks, so entitlements that arrived for something else don't close it.
  ///   - presentationId: When set, only that presentation is told and dismissed. One that has
  ///     ended meanwhile is left alone, and so is a newer one.
  @discardableResult
  private func dismissIfCovered(
    _ paywallVc: PaywallViewController,
    activeEntitlementIds: Set<String>,
    newlyCoveredBy newlyActiveIds: Set<String>? = nil,
    presentationId: UUID? = nil,
    superwall: Superwall
  ) async -> Bool {
    var paywallEntitlementIds: Set<String> = []
    for id in await paywallVc.info.productIds {
      let entitlements = superwall.entitlements.byProductId(id)
      paywallEntitlementIds.formUnion(entitlements.map { $0.id })
    }

    guard !paywallEntitlementIds.isEmpty,
      paywallEntitlementIds.subtracting(activeEntitlementIds).isEmpty else {
      return false
    }
    if let newlyActiveIds,
      paywallEntitlementIds.isDisjoint(with: newlyActiveIds) {
      return false
    }
    if let presentationId {
      if await Self.presentedPresentationId(of: paywallVc) != presentationId {
        return false
      }
      // Claimed before anything else waits, so two checks at once tell the presentation once.
      guard restoredPresentations.insert(presentationId).inserted else {
        return false
      }
    }

    let trackedEvent = await InternalSuperwallEvent.Restore(
      state: .complete,
      paywallInfo: paywallVc.info
    )
    await superwall.track(trackedEvent)

    // Tracking can wait, and the presentation may have ended or been replaced meanwhile:
    // its restore must not reach a newer presentation's page or close its checkout.
    if let presentationId,
      await Self.presentedPresentationId(of: paywallVc) != presentationId {
      return false
    }
    await paywallVc.webView.messageHandler.handle(PaywallMessage.restoreComplete)

    let superwallOptions = factory.makeSuperwallOptions()
    if superwallOptions.paywalls.automaticallyDismiss {
      if let presentationId {
        await MainActor.run {
          // Checked again in the same step as closing its browser.
          guard Self.presentedPresentationId(of: paywallVc) == presentationId else {
            return
          }
          paywallVc.closeSafari {
            // Checked again as the dismissal is asked for, in the same step.
            paywallVc.dismiss(
              presentation: presentationId,
              result: .restored,
              closeReason: .systemLogic
            )
          }
        }
      } else {
        await superwall.dismiss(paywallVc, result: PaywallResult.restored)
      }
    }
    return true
  }
  #endif
}

/// When web entitlements that weren't active before became active.
struct WebEntitlementsArrival: Equatable {
  let arrivedAt: Date
  /// The entitlements that became active.
  let newlyActiveIds: Set<String>

  /// An arrival when `webEntitlements` has an active entitlement `previousWebEntitlements`
  /// didn't, or `nil` when nothing new became active.
  init?(
    previousWebEntitlements: Set<Entitlement>,
    webEntitlements: Set<Entitlement>,
    arrivedAt: Date = Date()
  ) {
    let previouslyActive = Set(previousWebEntitlements.filter { $0.isActive }.map { $0.id })
    let active = Set(webEntitlements.filter { $0.isActive }.map { $0.id })
    let newlyActiveIds = active.subtracting(previouslyActive)
    guard !newlyActiveIds.isEmpty else {
      return nil
    }
    self.arrivedAt = arrivedAt
    self.newlyActiveIds = newlyActiveIds
  }

  /// Whether the entitlements arrived after an audience evaluated at `evaluatedAt`, so it
  /// couldn't have seen them. Nil, for a paywall with no placement or audience, never counts.
  func cameAfter(_ evaluatedAt: Date?) -> Bool {
    guard let evaluatedAt = evaluatedAt else {
      return false
    }
    return arrivedAt > evaluatedAt
  }
}
