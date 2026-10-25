//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/03/2025.
//
// swiftlint:disable type_body_length function_body_length trailing_closure file_length

import Foundation
import UIKit

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

/// Refreshes entitlements from the server after a custom product purchase.
protocol CustomPurchaseEntitlementsRefreshing: Sendable {
  func refreshEntitlementsAfterCustomPurchase(expecting entitlementIds: Set<String>) async
}

actor WebEntitlementRedeemer: CustomPurchaseEntitlementsRefreshing {
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
  /// How long to wait before each entitlements fetch after a custom product purchase.
  private let customPurchaseRefreshDelaysNs: [UInt64]
  private var isProcessing = false
  /// The throttled entitlements poll in flight, which concurrent polls wait on.
  private var inFlightWebEntitlementsPoll: Task<Void, Never>?
  /// How many entitlements fetches have started, and which of them last saved
  /// its response. A response that arrives after a newer fetch's is dropped.
  private var entitlementsFetchCount = 0
  private var lastSavedEntitlementsFetch = 0
  private var hasActiveStripePoll = false
  private var lastCompletedStripePollResult: (contextId: String, outcome: StripePollOutcome)?
  private var awaitingCheckoutComplete = false
  /// The checkout the paywall last reported complete, while it's being finished. An older
  /// checkout's poll stops for it, so it doesn't wait behind a poll that can't redeem it.
  private var completingCheckoutContextId: String?
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
    customPurchaseRefreshDelaysNs: [UInt64] = [1_000_000_000, 3_000_000_000, 6_000_000_000],
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
    self.customPurchaseRefreshDelaysNs = customPurchaseRefreshDelaysNs

    // Observe when the app enters the foreground
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppForeground),
      name: UIApplication.willEnterForegroundNotification,
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
      await pollPendingStripeCheckoutOnForegroundIfNeeded()
    }
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

  func handleStripeCheckoutComplete(
    contextId: String,
    productId: String,
    completion: StripeCheckoutCompletion = .restore
  ) async {
    awaitingCheckoutComplete = false

    // The page can report one purchase more than once (its status poll and the return check).
    // Redeemed once is enough: a second redemption would put the spinner back up behind the
    // success alert, with nothing left to take it down.
    if isRedeemed(contextId) {
      let superwall = self.superwall ?? Superwall.shared
      await MainActor.run {
        // The success alert's close takes the spinner down once the purchase is finished.
        let paywallViewController = superwall.paywallViewController
        if !(paywallViewController?.presentedViewController is UIAlertController) {
          paywallViewController?.loadingState = .ready
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
        superwall.paywallViewController?.loadingState = .ready
      }
    }
  }

  func handleStripeCheckoutAbandon(productId: String) async {
    awaitingCheckoutComplete = false
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

      let hasPaywall = await MainActor.run { superwall.paywallViewController != nil }

      if hasPaywall {
        isProcessing = true
        shouldCleanupProcessingFlag = true
      }
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
      let response = try await network.redeemEntitlements(request: request)
      await handleRedemptionSuccess(
        response: response,
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
    await MainActor.run {
      superwall.paywallViewController?.loadingState = .manualLoading
      superwall.paywallViewController?.closeSafari()
    }
    await delegate.willRedeemLink()
  }

  private func handleRedemptionSuccess(
    response: RedeemResponse,
    type: RedeemType,
    superwall: Superwall,
    callbackMode: RedemptionCallbackMode,
    completion: StripeCheckoutCompletion = .restore,
    checkoutContextId: String? = nil
  ) async {
    storage.save(Date(), forType: LastWebEntitlementsFetchDate.self)

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

    storage.save(response, forType: LatestRedeemResponse.self)

    await mergeAndApplyCustomerInfo(
      webCustomerInfo: response.customerInfo,
      superwall: superwall
    )

    await updateSubscriptionStatus(with: allEntitlements, superwall: superwall)

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
    let deviceCustomerInfo = storage.get(LatestDeviceCustomerInfo.self) ?? .blank()
    let activeDeviceEntitlements = Set(deviceCustomerInfo.entitlements.filter { $0.isActive })
    let combinedEntitlements =
      Array(activeDeviceEntitlements) + Array(response.customerInfo.entitlements)
    let allEntitlements = Entitlement.mergePrioritized(combinedEntitlements)

    var paywallEntitlementIds: Set<String> = []

    // A restore is only complete once every entitlement the paywall offers is active, and the
    // paywall hears restore_complete or restore_fail. A purchase bought one product, so none of
    // that applies: it hears transaction_complete instead.
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

    return (allEntitlements, paywallEntitlementIds)
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
    let showConfirmation = superwallOptions.paywalls.shouldShowWebPurchaseConfirmationAlert

    func afterRedeem() async {
      if callbackMode == .pollFakeCompatibility {
        await self.delegate.willRedeemLink()
        try? await Task.sleep(nanoseconds: 200_000_000)
        await self.delegate.didRedeemLink(result: codeResult)
      }

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

      switch completion {
      case .restore:
        if let paywallVc = superwall.paywallViewController,
          !paywallEntitlementIds.isEmpty,
          paywallEntitlementIds.subtracting(allEntitlementIds).isEmpty,
          superwallOptions.paywalls.automaticallyDismiss {
          await superwall.dismiss(paywallVc, result: .restored)
        }
      case let .purchase(productId, shouldDismiss):
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
      }

      await MainActor.run {
        superwall.paywallViewController?.loadingState = .ready
      }

      if callbackMode == .legacy {
        await self.delegate.didRedeemLink(result: codeResult)
      }
    }

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
  }

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
    guard let topVc = UIViewController.topMostViewController else {
      onClose?()
      return
    }
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
  }

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
      if let paywallVc = superwall.paywallViewController {
        await trackRestorationFailure(
          paywallViewController: paywallVc,
          message: error.localizedDescription,
          superwall: superwall
        )
      }

      let errorResult = RedemptionResult.error(
        code: code,
        error: RedemptionResult.ErrorInfo(message: error.localizedDescription)
      )

      await MainActor.run {
        superwall.paywallViewController?.loadingState = .ready
      }
      await delegate.didRedeemLink(result: errorResult)
    }

    Logger.debug(
      logLevel: .error,
      scope: .webEntitlements,
      message: "Failed to redeem",
      info: [:]
    )
  }

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
          await handleRedemptionSuccess(
            response: response,
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

    let shouldShowLoading = hasVisiblePaywall && shouldShowStripeRecoveryLoadingOnPaywallOpen()

    if shouldShowLoading {
      await MainActor.run {
        superwall.paywallViewController?.loadingState = .manualLoading
      }
    }

    await pollPendingStripeCheckoutOnForegroundIfNeeded()

    if shouldShowLoading {
      await MainActor.run {
        if superwall.paywallViewController?.loadingState == .manualLoading {
          superwall.paywallViewController?.loadingState = .ready
        }
      }
    }

    await pollWebEntitlements()
  }

  private func hasStripePendingTimedOut(_ state: PendingStripeCheckoutPollState) -> Bool {
    let elapsed = Date().timeIntervalSince(state.updatedAt)
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

  /// Refreshes entitlements after a custom product purchase until the
  /// purchased product's entitlements are active, or the attempts run out.
  ///
  /// The developer's server reports the purchase to Superwall, which can lag
  /// the purchase on the device, so each attempt waits a little longer than
  /// the last. Stops early if the task is cancelled or the user changes.
  ///
  /// - Parameter entitlementIds: The IDs of the purchased product's
  ///   entitlements. When empty, the first successful fetch ends the refresh.
  func refreshEntitlementsAfterCustomPurchase(expecting entitlementIds: Set<String>) async {
    let appUserId = factory.makeAppUserId()
    for (index, delay) in customPurchaseRefreshDelaysNs.enumerated() {
      do {
        try await Task.sleep(nanoseconds: delay)
      } catch {
        return
      }

      if factory.makeAppUserId() != appUserId {
        Logger.debug(
          logLevel: .debug,
          scope: .webEntitlements,
          message: "Stopped refreshing entitlements after a custom product purchase because the user changed."
        )
        return
      }

      guard let customerInfo = await refreshWebEntitlements() else {
        continue
      }
      let activeEntitlementIds = Set(customerInfo.entitlements.filter { $0.isActive }.map { $0.id })
      if entitlementIds.isSubset(of: activeEntitlementIds) {
        Logger.debug(
          logLevel: .debug,
          scope: .webEntitlements,
          message: "Entitlements refreshed after custom product purchase",
          info: ["attempt": index + 1]
        )
        return
      }
    }

    Logger.debug(
      logLevel: .warn,
      scope: .webEntitlements,
      message: "The purchased custom product's entitlements weren't active after "
        + "\(customPurchaseRefreshDelaysNs.count) attempts. Check that your server reports "
        + "the purchase to Superwall.",
      info: ["entitlement_ids": entitlementIds.sorted().joined(separator: ",")]
    )
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
  // swiftlint:disable:next cyclomatic_complexity
  func refreshWebEntitlements(dismissesCoveredPaywall: Bool = false) async -> CustomerInfo? {
    entitlementsFetchCount += 1
    let fetch = entitlementsFetchCount
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

        // If there's a paywall, check if we should dismiss it
        // A purchase in progress, such as one in a custom store's checkout,
        // reports its own result, so its entitlements aren't a restore.
        if dismissesCoveredPaywall,
          await factory.makePurchasingCoordinator().source == nil,
          let paywallVc = superwall.paywallViewController {
          // Get entitlement IDs of products from paywall
          var paywallEntitlementIds: Set<String> = []
          for id in await paywallVc.info.productIds {
            let entitlements = superwall.entitlements.byProductId(id)
            paywallEntitlementIds.formUnion(entitlements.map { $0.id })
          }

          // If the restored entitlements cover the paywall entitlements, track and dismiss
          let activeEntitlementsIds = Set(activeEntitlements.map { $0.id })
          if !paywallEntitlementIds.isEmpty,
            paywallEntitlementIds.subtracting(activeEntitlementsIds).isEmpty {
            let trackedEvent = await InternalSuperwallEvent.Restore(
              state: .complete,
              paywallInfo: paywallVc.info
            )
            await superwall.track(trackedEvent)

            await paywallVc.webView.messageHandler.handle(PaywallMessage.restoreComplete)

            let superwallOptions = factory.makeSuperwallOptions()
            if superwallOptions.paywalls.automaticallyDismiss {
              await superwall.dismiss(paywallVc, result: PaywallResult.restored)
            }
          }
        }
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
}
