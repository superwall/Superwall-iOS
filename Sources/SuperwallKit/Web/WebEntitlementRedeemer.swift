//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/03/2025.
//
// swiftlint:disable type_body_length function_body_length trailing_closure file_length

import UIKit
import Foundation

struct PendingStripeCheckoutPollState: Codable, Equatable {
  static let defaultForegroundAttempts = 5

  let checkoutContextId: String
  let productId: String
  let remainingForegroundAttempts: Int
  let updatedAt: Date

  init(
    checkoutContextId: String,
    productId: String,
    remainingForegroundAttempts: Int = defaultForegroundAttempts,
    updatedAt: Date = Date()
  ) {
    self.checkoutContextId = checkoutContextId
    self.productId = productId
    self.remainingForegroundAttempts = remainingForegroundAttempts
    self.updatedAt = updatedAt
  }

  func consumingForegroundAttempt() -> PendingStripeCheckoutPollState {
    PendingStripeCheckoutPollState(
      checkoutContextId: checkoutContextId,
      productId: productId,
      remainingForegroundAttempts: max(remainingForegroundAttempts - 1, 0),
      updatedAt: Date()
    )
  }
}

actor WebEntitlementRedeemer {
  private unowned let network: Network
  private unowned let storage: Storage
  private unowned let entitlementsInfo: EntitlementsInfo
  private unowned let delegate: SuperwallDelegateAdapter
  private unowned let purchaseController: PurchaseController
  private unowned let receiptManager: ReceiptManager
  private unowned let factory: Factory
  private var isProcessing = false
  private var activeStripePollContextId: String?
  private var superwall: Superwall?
  typealias Factory = WebEntitlementFactory
    & OptionsFactory
    & ConfigStateFactory
    & ConfigManagerFactory
    & HasExternalPurchaseControllerFactory
    & DeviceHelperFactory

  private enum StripePollTrigger: String {
    case checkoutComplete = "checkout_complete"
    case foreground = "foreground"
  }

  private enum StripePollOutcome {
    case redeemed
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
    superwall: Superwall? = nil
  ) {
    self.network = network
    self.storage = storage
    self.entitlementsInfo = entitlementsInfo
    self.delegate = delegate
    self.purchaseController = purchaseController
    self.factory = factory
    self.superwall = superwall
    self.receiptManager = receiptManager

    // Observe when the app enters the foreground
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )

    // Also check once on SDK initialization so pending Stripe checkouts can be
    // recovered on cold launch.
    Task {
      if factory.makeConfigManager() == nil {
        return
      }
      await pollPendingStripeCheckoutOnForegroundIfNeeded()
    }
  }

  func registerStripeCheckoutStart(
    contextId: String,
    productId: String
  ) {
    savePendingStripeCheckoutState(
      .init(
        checkoutContextId: contextId,
        productId: productId
      )
    )
  }

  func handleStripeCheckoutComplete(
    contextId: String,
    productId: String
  ) async {
    savePendingStripeCheckoutState(
      .init(
        checkoutContextId: contextId,
        productId: productId
      )
    )

    let outcome = await pollStripeRedemptionResult(
      contextId: contextId,
      productId: productId,
      trigger: .checkoutComplete
    )

    if outcome != .redeemed {
      let superwall = self.superwall ?? Superwall.shared
      await MainActor.run {
        superwall.paywallViewController?.loadingState = .ready
      }
    }
  }

  func handleStripeCheckoutAbandon(productId: String) async {
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
    guard outcome != .skippedInFlight else {
      return
    }

    guard let latestState = pendingStripeCheckoutState,
      latestState.checkoutContextId == pendingState.checkoutContextId else {
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
    guard case .code = type else {
      if case .existingCodes = type {
        let startEvent = InternalSuperwallEvent.Redemption(state: .start, type: type)
        await superwall.track(startEvent)
      }
      return
    }
    let startEvent = InternalSuperwallEvent.Redemption(state: .start, type: type)
    await superwall.track(startEvent)
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

    if case .code = type {
      let completeEvent = InternalSuperwallEvent.Redemption(state: .complete, type: type)
      await superwall.track(completeEvent)
    } else if case .existingCodes = type {
      let completeEvent = InternalSuperwallEvent.Redemption(state: .complete, type: type)
      await superwall.track(completeEvent)
    }

    let (allEntitlements, paywallEntitlementIds) = await processEntitlements(
      response: response,
      type: type,
      superwall: superwall
    )

    storage.save(response, forType: LatestRedeemResponse.self)

    // Merge device and web CustomerInfo
    // If using an external purchase controller, also preserve entitlements that came from it
    let mergedCustomerInfo: CustomerInfo
    if factory.makeHasExternalPurchaseController() {
      let subscriptionStatus = await MainActor.run { superwall.subscriptionStatus }
      mergedCustomerInfo = CustomerInfo.forExternalPurchaseController(
        storage: storage,
        subscriptionStatus: subscriptionStatus
      )
    } else {
      let deviceCustomerInfo = storage.get(LatestDeviceCustomerInfo.self) ?? .blank()
      mergedCustomerInfo = deviceCustomerInfo.merging(with: response.customerInfo)
    }

    // Update Superwall's CustomerInfo with the merged result
    await MainActor.run {
      superwall.customerInfo = mergedCustomerInfo
    }

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
    let combinedEntitlements = Array(activeDeviceEntitlements) + Array(response.customerInfo.entitlements)
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

  private func updateSubscriptionStatus(
    with allEntitlements: Set<Entitlement>,
    superwall: Superwall
  ) async {
    let activeEntitlements = allEntitlements.filter { $0.isActive }
    let status: SubscriptionStatus = activeEntitlements.isEmpty ? .inactive : .active(activeEntitlements)
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
        await NotificationScheduler.shared.scheduleNotifications(
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

    if showConfirmation,
      let paywallVc = superwall.paywallViewController {
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

      await paywallVc.presentAlert(
        title: title,
        message: message,
        closeActionTitle: closeActionTitle,
        onClose: {
          Task {
            await afterRedeem()
          }
        }
      )
    } else {
      await afterRedeem()
    }
  }

  private func handleRedemptionFailure(
    error: Error,
    type: RedeemType,
    latestRedeemResponse: RedeemResponse?,
    superwall: Superwall
  ) async {
    if case .code = type {
      let event = InternalSuperwallEvent.Redemption(state: .fail, type: type)
      await superwall.track(event)
    } else if case .existingCodes = type {
      let event = InternalSuperwallEvent.Redemption(state: .fail, type: type)
      await superwall.track(event)
    }

    if case let .code(code) = type {
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

  private func createPollRedemptionRequest(
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
    if activeStripePollContextId != nil {
      return .skippedInFlight
    }

    activeStripePollContextId = contextId
    defer {
      activeStripePollContextId = nil
    }

    let request = createPollRedemptionRequest(contextId: contextId)
    let retryBackoffsNs: [UInt64] = [1_000_000_000, 2_000_000_000, 4_000_000_000]

    for attempt in 0...retryBackoffsNs.count {
      do {
        let response = try await network.pollRedemptionResult(request: request)

        guard let code = response.results.first?.code else {
          if attempt < retryBackoffsNs.count {
            try? await Task.sleep(nanoseconds: retryBackoffsNs[attempt])
            continue
          }
          return .noRedemptionFound
        }

        let superwall = superwall ?? Superwall.shared
        await handleRedemptionSuccess(
          response: response,
          type: .code(code),
          superwall: superwall,
          callbackMode: .pollFakeCompatibility
        )
        clearPendingStripeCheckoutState()
        return .redeemed
      } catch {
        // Intentional: we don't retry network failures in this trigger.
        // Pending state remains persisted, so recovery continues on subsequent foreground polls.
        Logger.debug(
          logLevel: .warn,
          scope: .webEntitlements,
          message: "Stripe poll-redemption-result failed",
          info: [
            "checkout_context_id": contextId,
            "product_id": productId,
            "trigger": trigger.rawValue,
            "attempt": attempt + 1
          ],
          error: error
        )
        return .requestFailed
      }
    }

    return .noRedemptionFound
  }

  @objc
  nonisolated private func handleAppForeground() {
    Task {
      if factory.makeConfigManager() == nil {
        return
      }
      await pollPendingStripeCheckoutOnForegroundIfNeeded()
      await pollWebEntitlements()
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  func pollWebEntitlements(
    config: Config? = nil,
    isFirstTime: Bool = false
  ) async {
    if !isFirstTime {
      if let entitlementsMaxAge = config?.web2appConfig?.entitlementsMaxAge ?? factory.makeEntitlementsMaxAge() {
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
      let existingWebEntitlements = Set(storage.get(LatestRedeemResponse.self)?.customerInfo.entitlements ?? [])

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

        // Merge device and web CustomerInfo
        // If using an external purchase controller, also preserve entitlements that came from it
        let mergedCustomerInfo: CustomerInfo
        if factory.makeHasExternalPurchaseController() {
          let subscriptionStatus = await MainActor.run { superwall.subscriptionStatus }
          mergedCustomerInfo = CustomerInfo.forExternalPurchaseController(
            storage: storage,
            subscriptionStatus: subscriptionStatus
          )
        } else {
          let deviceCustomerInfo = storage.get(LatestDeviceCustomerInfo.self) ?? .blank()
          mergedCustomerInfo = deviceCustomerInfo.merging(with: response.customerInfo)
        }

        // Update Superwall's CustomerInfo with the merged result
        await MainActor.run {
          superwall.customerInfo = mergedCustomerInfo
        }

        // Sets the subscription status internally if no external PurchaseController
        // Use the merged entitlements from CustomerInfo (already prioritized)
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
