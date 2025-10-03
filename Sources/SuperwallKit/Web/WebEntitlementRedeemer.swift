//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/03/2025.
//
// swiftlint:disable type_body_length trailing_closure file_length

import UIKit
import Foundation

actor WebEntitlementRedeemer {
  private unowned let network: Network
  private unowned let storage: Storage
  private unowned let entitlementsInfo: EntitlementsInfo
  private unowned let delegate: SuperwallDelegateAdapter
  private unowned let purchaseController: PurchaseController
  private unowned let receiptManager: ReceiptManager
  private unowned let factory: Factory
  private var isProcessing = false
  private var superwall: Superwall?
  typealias Factory = WebEntitlementFactory
    & OptionsFactory
    & ConfigStateFactory
    & ConfigManagerFactory

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
  }

  func redeem(
    _ type: RedeemType,
    injectedConfig: Config? = nil
  ) async {
    let superwall = superwall ?? Superwall.shared
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
        superwall: superwall
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
    superwall: Superwall
  ) async {
    storage.save(Date(), forType: LastWebEntitlementsFetchDate.self)

    if case .code = type {
      let completeEvent = InternalSuperwallEvent.Redemption(state: .complete, type: type)
      await superwall.track(completeEvent)
    } else if case .existingCodes = type {
      let completeEvent = InternalSuperwallEvent.Redemption(state: .complete, type: type)
      await superwall.track(completeEvent)
    }

    let (allEntitlements, paywallEntitlements) = await processEntitlements(
      response: response,
      type: type,
      superwall: superwall
    )

    storage.save(response, forType: LatestRedeemResponse.self)
    await updateSubscriptionStatus(with: allEntitlements, superwall: superwall)

    if case .code(let code) = type {
      await handleCodeRedemptionCompletion(
        code: code,
        response: response,
        allEntitlements: allEntitlements,
        paywallEntitlements: paywallEntitlements,
        superwall: superwall
      )
    }
  }

  private func processEntitlements(
    response: RedeemResponse,
    type: RedeemType,
    superwall: Superwall
  ) async -> (allEntitlements: Set<Entitlement>, paywallEntitlements: Set<Entitlement>) {
    let deviceEntitlements = entitlementsInfo.activeDeviceEntitlements
    let combinedEntitlements = Array(deviceEntitlements) + Array(response.customerInfo.entitlements)
    let allEntitlements = Entitlement.mergePrioritized(combinedEntitlements)

    var paywallEntitlements: Set<Entitlement> = []

    if case .code = type, let paywallVc = superwall.paywallViewController {
      for id in await paywallVc.info.productIds {
        paywallEntitlements.formUnion(Superwall.shared.entitlements.byProductId(id))
      }

      if paywallEntitlements.subtracting(allEntitlements).isEmpty {
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

    return (allEntitlements, paywallEntitlements)
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
    allEntitlements: Set<Entitlement>,
    paywallEntitlements: Set<Entitlement>,
    superwall: Superwall
  ) async {
    guard let codeResult = response.results.first(where: { $0.code == code }) else { return }

    let superwallOptions = factory.makeSuperwallOptions()
    let showConfirmation = superwallOptions.paywalls.shouldShowWebPurchaseConfirmationAlert

    func afterRedeem() async {
      if let paywallVc = superwall.paywallViewController,
        paywallEntitlements.subtracting(allEntitlements).isEmpty,
        superwallOptions.paywalls.automaticallyDismiss {
        await superwall.dismiss(paywallVc, result: .restored)
      }

      await MainActor.run {
        superwall.paywallViewController?.loadingState = .ready
      }
      await self.delegate.didRedeemLink(result: codeResult)
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

      await superwall.paywallViewController?.presentAlert(
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

  @objc
  nonisolated private func handleAppForeground() {
    Task {
      if await factory.makeConfigManager() == nil {
        return
      }
      await pollWebEntitlements()
    }
  }

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
        // Don't proceed at all if there's no web2app config
        return
      }
    }

    do {
      let existingWebEntitlements = Set(storage.get(LatestRedeemResponse.self)?.customerInfo.entitlements ?? [])

      // TODO: Need products_v3 to work

      let response = try await network.getEntitlements(
        appUserId: factory.makeAppUserId(),
        deviceId: factory.makeDeviceId()
      )

      // Update the latest redeem response with the entitlements and customer info from the response.
      if var latestRedeemResponse = storage.get(LatestRedeemResponse.self) {
        latestRedeemResponse.customerInfo = response.customerInfo
        storage.save(latestRedeemResponse, forType: LatestRedeemResponse.self)
      }

      storage.save(Date(), forType: LastWebEntitlementsFetchDate.self)

      let webEntitlements = Set(response.customerInfo.entitlements)
      if existingWebEntitlements != webEntitlements {
        // Sets the subscription status internally if no external PurchaseController
        let deviceEntitlements = entitlementsInfo.activeDeviceEntitlements

        // Merge web and device entitlements with prioritization
        // This ensures the highest priority entitlement is kept for each ID
        let combinedEntitlements = Array(deviceEntitlements) + Array(webEntitlements)
        let mergedEntitlements = Entitlement.mergePrioritized(combinedEntitlements)

        // Filter to only active entitlements
        let activeEntitlements = mergedEntitlements.filter { $0.isActive }

        if activeEntitlements.isEmpty {
          await Superwall.shared.internallySetSubscriptionStatus(to: .inactive)
        } else {
          await Superwall.shared.internallySetSubscriptionStatus(to: .active(activeEntitlements))
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
