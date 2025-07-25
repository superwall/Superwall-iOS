//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/03/2025.
//
// swiftlint:disable function_body_length cyclomatic_complexity type_body_length trailing_closure

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
  private var webCheckoutSessionId: String?
  typealias Factory = WebEntitlementFactory
    & OptionsFactory
    & ConfigStateFactory
    & ConfigManagerFactory

  enum RedeemType: CustomStringConvertible {
    case code(String)
    case existingCodes

    var description: String {
      switch self {
      case .code:
        return "CODE"
      case .existingCodes:
        return "EXISTING_CODES"
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

  func startWebCheckoutSession(withId sessionId: String) {
    webCheckoutSessionId = sessionId
  }

  func redeem(
    _ type: RedeemType,
    injectedConfig: Config? = nil
  ) async {
    // Await for config or use injected config.
    var config = injectedConfig

    if config == nil {
      let configState = factory.makeConfigState()
      config = try? await configState
        .compactMap { $0.getConfig() }
        .throwableAsync()
    }

    guard let config = config else {
      return
    }
    // Make sure web2app is enabled
    if config.web2appConfig == nil {
      return
    }

    // Prepare data to redeem
    let superwall = superwall ?? Superwall.shared
    let latestRedeemResponse = storage.get(LatestRedeemResponse.self)

    var allCodes = latestRedeemResponse?.allCodes ?? []

    switch type {
    case .code(let code):
      // If redeeming a code, add it to list of existing codes,
      // marking as first redemption or not.
      var isFirstRedemption = true

      if !allCodes.isEmpty {
        // If we have codes, isFirstRedemption is false if we already have the code
        isFirstRedemption = !allCodes.contains { $0.code == code }
      }

      let redeemable = Redeemable(
        code: code,
        isFirstRedemption: isFirstRedemption
      )
      allCodes.insert(redeemable)

      if let paywallVc = superwall.paywallViewController {
        let trackedEvent = await InternalSuperwallEvent.Restore(
          state: .start,
          paywallInfo: paywallVc.info
        )
        await superwall.track(trackedEvent)
      }
    case .existingCodes:
      break
    }

    // Create request to redeem
    let request = await RedeemRequest(
      deviceId: factory.makeDeviceId(),
      appUserId: factory.makeAppUserId(),
      aliasId: factory.makeAliasId(),
      codes: allCodes,
      receipts: receiptManager.getTransactionReceipts(),
      appTransactionId: ReceiptManager.appTransactionId
    )

    let startEvent = InternalSuperwallEvent.Redemption(
      state: .start,
      type: type
    )
    await superwall.track(startEvent)

    // Close safari if open and show spinner, then call delegate
    switch type {
    case .code:
      await MainActor.run {
        superwall.paywallViewController?.loadingState = .manualLoading
        superwall.paywallViewController?.closeSafari()
      }
      await delegate.willRedeemLink()
    case .existingCodes:
      break
    }

    do {
      // Redeem
      let response = try await network.redeemEntitlements(request: request)

      storage.save(Date(), forType: LastWebEntitlementsFetchDate.self)

      let completeEvent = InternalSuperwallEvent.Redemption(
        state: .complete,
        type: type
      )
      await superwall.track(completeEvent)

      let deviceEntitlements = entitlementsInfo.activeDeviceEntitlements
      let allEntitlements = deviceEntitlements.union(response.entitlements)

      // Get entitlements of products from paywall.
      var paywallEntitlements: Set<Entitlement> = []
      if case .code = type,
        let paywallVc = superwall.paywallViewController {
        for id in await paywallVc.info.productIds {
          paywallEntitlements.formUnion(Superwall.shared.entitlements.byProductId(id))
        }

        // If the restored entitlements cover the paywall entitlements,
        // track successful restore
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

      storage.save(response, forType: LatestRedeemResponse.self)

      await superwall.internallySetSubscriptionStatus(
        to: .active(allEntitlements),
        superwall: superwall
      )

      // Call the delegate if user try to redeem a code,
      // then close the paywall.
      if case let .code(code) = type {
        if let codeResult = response.results.first(where: { $0.code == code }) {
          let superwallOptions = factory.makeSuperwallOptions()
          let showConfirmation = superwallOptions.paywalls.shouldShowWebPurchaseConfirmationAlert

          func afterRedeem() async {
            if let paywallVc = superwall.paywallViewController,
              paywallEntitlements.subtracting(allEntitlements).isEmpty {
              if superwallOptions.paywalls.automaticallyDismiss {
                await superwall.dismiss(paywallVc, result: .restored)
              }
            }

            await MainActor.run {
              superwall.paywallViewController?.loadingState = .ready
            }
            await self.delegate.didRedeemLink(result: codeResult)
          }

          if showConfirmation {
            let title = LocalizationLogic
              .localizedBundle()
              .localizedString(
                forKey: "purchase_success_title",
                value: nil,
                table: nil
              )
            let message = LocalizationLogic
              .localizedBundle()
              .localizedString(
                forKey: "purchase_success_message",
                value: nil,
                table: nil
              )
            let closeActionTitle = LocalizationLogic
              .localizedBundle()
              .localizedString(
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
      }
    } catch {
      let event = InternalSuperwallEvent.Redemption(
        state: .fail,
        type: type
      )
      await superwall.track(event)

      // Call the delegate if user try to redeem a code
      if case let .code(code) = type {
        if let paywallVc = superwall.paywallViewController {
          await trackRestorationFailure(
            paywallViewController: paywallVc,
            message: error.localizedDescription,
            superwall: superwall
          )
        }
        var redemptions = latestRedeemResponse?.results ?? []
        let errorResult = RedemptionResult.error(
          code: code,
          error: RedemptionResult.ErrorInfo(
            message: error.localizedDescription
          )
        )
        redemptions.append(errorResult)

        await MainActor.run {
          superwall.paywallViewController?.loadingState = .ready
        }
        await delegate.didRedeemLink(result: errorResult)
      }

      Logger.debug(
        logLevel: .error,
        scope: .webEntitlements,
        message: "Failed to redeem purchase token",
        info: [:]
      )
    }
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
      await checkForWebCheckoutCompletion()
    }
    Task {
      if await factory.makeConfigManager() == nil {
        return
      }
      await pollWebEntitlements()
    }
  }

  private func checkForWebCheckoutCompletion() async {
    guard let sessionId = webCheckoutSessionId else {
      return
    }
    do {
      let response = try await network.getWebCheckoutStatus(sessionId: sessionId)
      switch response.status {
      case .abandoned(let abandoned):
        // Need more product info to construct the abandon,
        break
//        if let paywallViewController = Superwall.shared.paywallViewController {
//          let product = StoreProduct
//          let transactionAbandon = InternalSuperwallEvent.Transaction(
//            state: .abandon(product),
//            paywallInfo: paywallViewController.info,
//            product: product,
//            transaction: nil,
//            source: .internal,
//            isObserved: false,
//            storeKitVersion: nil
//          )
//          await Superwall.shared.track(transactionAbandon)
//          await paywallViewController.webView.messageHandler.handle(.transactionAbandon)
//        }
      case .completed(let redemptionCodes):
        break
       // redeem(.code(rede))
      case .pending:
        break
        // TODO: Retry with exponential backoff?
      }
    } catch {

    }
  }

  func pollWebEntitlements(
    config: Config? = nil,
    isFirstTime: Bool = false
  ) async {
    guard let entitlementsMaxAge = config?.web2appConfig?.entitlementsMaxAge ?? factory.makeEntitlementsMaxAge() else {
      return
    }

    if !isFirstTime,
      let lastFetchedWebEntitlementsAt = storage.get(LastWebEntitlementsFetchDate.self) {
      let timeElapsed = Date().timeIntervalSince(lastFetchedWebEntitlementsAt)
      guard timeElapsed > entitlementsMaxAge else {
        return
      }
    }

    do {
      let existingWebEntitlements = storage.get(LatestRedeemResponse.self)?.entitlements ?? []

      let entitlements = try await network.redeemEntitlements(
        appUserId: factory.makeAppUserId(),
        deviceId: factory.makeDeviceId()
      )

      // Update the latest redeem response with the entitlements.
      if var latestRedeemResponse = storage.get(LatestRedeemResponse.self) {
        latestRedeemResponse.entitlements = entitlements
        storage.save(latestRedeemResponse, forType: LatestRedeemResponse.self)
      }

      storage.save(Date(), forType: LastWebEntitlementsFetchDate.self)

      if existingWebEntitlements != entitlements {
        // Sets the subscription status internally if no external PurchaseController
        let deviceEntitlements = entitlementsInfo.activeDeviceEntitlements
        let allEntitlements = deviceEntitlements.union(entitlements)
        await Superwall.shared.internallySetSubscriptionStatus(to: .active(allEntitlements))
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
