//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/03/2025.
//
// swiftlint:disable type_body_length function_body_length trailing_closure file_length

import Foundation
import UIKit

actor WebEntitlementRedeemer {
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
  private var hasActiveStripePoll = false
  private var lastCompletedStripePollResult: (contextId: String, outcome: StripePollOutcome)?
  private var awaitingCheckoutComplete = false
  private var superwall: Superwall?
  typealias Factory = WebEntitlementFactory
    & OptionsFactory
    & ConfigStateFactory
    & HasExternalPurchaseControllerFactory
    & DeviceHelperFactory

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

    // Observe when the app enters the foreground
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )

    // Also check once on SDK initialization so pending Stripe checkouts can be
    // recovered on cold launch. Guard on factory readiness to avoid accessing
    // dependencies (e.g. deviceHelper) before the container is fully set up.
    Task {
      guard factory.makeIsContainerReady() else { return }
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
      let waitStart = DispatchTime.now().uptimeNanoseconds
      while hasActiveStripePoll {
        if Task.isCancelled {
          return false
        }
        let elapsed = DispatchTime.now().uptimeNanoseconds - waitStart
        if elapsed >= stripePendingPollTimeoutNs {
          return false
        }
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
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
      trigger: .paywallOpen
    )

    return outcome == .redeemed
  }

  func handleStripeCheckoutComplete(
    contextId: String,
    productId: String
  ) async {
    awaitingCheckoutComplete = false

    if let existingState = pendingStripeCheckoutState,
      existingState.checkoutContextId == contextId {
      savePendingStripeCheckoutState(
        .init(
          checkoutContextId: contextId,
          productId: productId,
          remainingForegroundAttempts: existingState.remainingForegroundAttempts
        )
      )
    } else {
      savePendingStripeCheckoutState(
        .init(
          checkoutContextId: contextId,
          productId: productId
        )
      )
    }

    let outcome = await pollStripeRedemptionResult(
      contextId: contextId,
      productId: productId,
      trigger: .checkoutComplete
    )

    // Don't hide spinner if another poll is in-flight — it will handle the
    // loading state when it finishes.
    if outcome != .redeemed, outcome != .skippedInFlight {
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
      product: nil,
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
      trigger: .foreground
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
    callbackMode: RedemptionCallbackMode
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
      superwall: superwall
    )

    storage.save(response, forType: LatestRedeemResponse.self)

    _ = await mergeAndApplyCustomerInfo(
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
        callbackMode: callbackMode
      )
    }
  }

  private func processEntitlements(
    response: RedeemResponse,
    type: RedeemType,
    superwall: Superwall
  ) async -> (allEntitlements: Set<Entitlement>, paywallEntitlementIds: Set<String>) {
    let deviceCustomerInfo = storage.get(LatestDeviceCustomerInfo.self) ?? .blank()
    let activeDeviceEntitlements = Set(deviceCustomerInfo.entitlements.filter { $0.isActive })
    let combinedEntitlements =
      Array(activeDeviceEntitlements) + Array(response.customerInfo.entitlements)
    let allEntitlements = Entitlement.mergePrioritized(combinedEntitlements)

    var paywallEntitlementIds: Set<String> = []

    if case .code = type, let paywallVc = superwall.paywallViewController {
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
  ) async -> CustomerInfo {
    let mergedCustomerInfo: CustomerInfo
    if factory.makeHasExternalPurchaseController() {
      let subscriptionStatus = await MainActor.run { superwall.subscriptionStatus }
      mergedCustomerInfo = CustomerInfo.forExternalPurchaseController(
        storage: storage,
        subscriptionStatus: subscriptionStatus
      )
    } else {
      let deviceCustomerInfo = storage.get(LatestDeviceCustomerInfo.self) ?? .blank()
      mergedCustomerInfo = deviceCustomerInfo.merging(with: webCustomerInfo)
    }

    await MainActor.run {
      superwall.customerInfo = mergedCustomerInfo
    }

    return mergedCustomerInfo
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
    callbackMode: RedemptionCallbackMode
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

      // Schedule free trial notification if applicable
      if case .success(_, let redemptionInfo) = codeResult,
        let product = redemptionInfo.paywallInfo?.product,
        product.trialPeriodDays > 0,
        let paywallVc = superwall.paywallViewController {
        let paywallInfo = await paywallVc.info
        let notifications = paywallInfo.localNotifications.filter {
          $0.type == .trialStarted
        }
        await self.notificationScheduler.scheduleNotifications(
          notifications,
          fromPaywallId: paywallInfo.identifier,
          factory: self.factory
        )
      }

      if let paywallVc = superwall.paywallViewController,
        !paywallEntitlementIds.isEmpty,
        paywallEntitlementIds.subtracting(allEntitlementIds).isEmpty,
        superwallOptions.paywalls.automaticallyDismiss {
        await superwall.dismiss(paywallVc, result: .restored)
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
          onClose: {
            Task { [weak self] in
              await afterRedeem()
              await self?.clearPendingStripeCheckoutState()
            }
          }
        )
      } else {
        await presentAlertOnTopViewController(
          title: title,
          message: message,
          closeActionTitle: closeActionTitle,
          onClose: {
            Task { [weak self] in
              await afterRedeem()
              await self?.clearPendingStripeCheckoutState()
            }
          }
        )
      }
    } else {
      await afterRedeem()
      clearPendingStripeCheckoutState()
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
    trigger: StripePollTrigger
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

      do {
        let response = try await network.pollRedemptionResult(request: request)

        if let code = response.results.first?.code {
          let superwall = superwall ?? Superwall.shared
          await handleRedemptionSuccess(
            response: response,
            type: .code(code),
            superwall: superwall,
            callbackMode: .pollFakeCompatibility
          )
          finalOutcome = .redeemed
          return finalOutcome
        }

        switch response.status {
        case .failed:
          clearPendingStripeCheckoutState()
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
          clearPendingStripeCheckoutState()
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

  // swiftlint:disable:next cyclomatic_complexity
  func pollWebEntitlements(
    config: Config? = nil,
    isFirstTime: Bool = false
  ) async {
    if !isFirstTime {
      if let entitlementsMaxAge = config?.web2appConfig?.entitlementsMaxAge
        ?? factory.makeEntitlementsMaxAge() {
        if let lastFetchedWebEntitlementsAt = storage.get(LastWebEntitlementsFetchDate.self) {
          let timeElapsed = Date().timeIntervalSince(lastFetchedWebEntitlementsAt)
          // Only proceed if a certain amount of time has elapsed
          guard timeElapsed > entitlementsMaxAge else {
            return
          }
        }
      } else {
        // Don't proceed at all if there's no web2app config and it's not a UI test
        if !ProcessInfo.processInfo.arguments.contains("SUPERWALL_UI_TESTS") {
          return
        }
      }
    }

    do {
      let existingWebEntitlements = Set(
        storage.get(LatestRedeemResponse.self)?.customerInfo.entitlements ?? [])

      let response = try await network.getEntitlements(
        appUserId: factory.makeAppUserId(),
        deviceId: factory.makeDeviceId()
      )

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

      let webEntitlements = Set(response.customerInfo.entitlements)
      if existingWebEntitlements != webEntitlements {
        // Use the injected superwall instance or fall back to shared
        let superwall = superwall ?? (Superwall.isInitialized ? Superwall.shared : nil)
        guard let superwall = superwall else {
          return
        }

        let mergedCustomerInfo = await mergeAndApplyCustomerInfo(
          webCustomerInfo: response.customerInfo,
          superwall: superwall
        )

        let activeEntitlements = Set(mergedCustomerInfo.entitlements.filter { $0.isActive })
        if activeEntitlements.isEmpty {
          await superwall.internallySetSubscriptionStatus(to: .inactive, superwall: superwall)
        } else {
          await superwall.internallySetSubscriptionStatus(
            to: .active(activeEntitlements),
            superwall: superwall
          )
        }

        // If there's a paywall, check if we should dismiss it
        if let paywallVc = superwall.paywallViewController {
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
    } catch {
      Logger.debug(
        logLevel: .warn,
        scope: .webEntitlements,
        message: "Polling web entitlements failed",
        error: error
      )
    }
  }
}
