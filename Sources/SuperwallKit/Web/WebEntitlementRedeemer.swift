//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/03/2025.
//
// swiftlint:disable function_body_length

import UIKit
import Foundation

actor WebEntitlementRedeemer {
  private unowned let network: Network
  private unowned let storage: Storage
  private unowned let entitlementsInfo: EntitlementsInfo
  private unowned let delegate: SuperwallDelegateAdapter
  private unowned let purchaseController: PurchaseController
  private unowned let factory: WebEntitlementFactory & OptionsFactory
  private var isProcessing = false

  enum RedeemType {
    case code(String)
    case existingCodes
  }

  init(
    network: Network,
    storage: Storage,
    entitlementsInfo: EntitlementsInfo,
    delegate: SuperwallDelegateAdapter,
    purchaseController: PurchaseController,
    factory: WebEntitlementFactory & OptionsFactory
  ) {
    self.network = network
    self.storage = storage
    self.entitlementsInfo = entitlementsInfo
    self.delegate = delegate
    self.purchaseController = purchaseController
    self.factory = factory

    // Observe when the app enters the foreground
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }

  func redeem(_ type: RedeemType) async {
    let latestRedeemResponse = storage.get(LatestRedeemResponse.self)

    do {
      var allCodes = latestRedeemResponse?.allCodes ?? []

      switch type {
      case .code(let code):
        // If redeeming a code, add it to list of existing codes,
        // marking as first redemption or not.
        var isFirstRedemption = true

        if !allCodes.isEmpty {
          // If we have codes, isFirstRedemption is false if we already have the code
          isFirstRedemption = !allCodes.contains(where: { $0.code == code })
        }

        let redeemable = Redeemable(
          code: code,
          isFirstRedemption: isFirstRedemption
        )
        allCodes.insert(redeemable)
      case .existingCodes:
        break
      }

      let request = RedeemRequest(
        deviceId: factory.makeDeviceId(),
        appUserId: factory.makeAppUserId(),
        aliasId: factory.makeAliasId(),
        codes: allCodes
      )

      if let paywallVc = Superwall.shared.paywallViewController {
        let trackedEvent = await InternalSuperwallEvent.Restore(
          state: .start,
          paywallInfo: paywallVc.info
        )
        await Superwall.shared.track(trackedEvent)
      }

      let startEvent = InternalSuperwallEvent.Redemption(state: .start)
      await Superwall.shared.track(startEvent)

      let response = try await network.redeemEntitlements(request: request)

      storage.save(Date(), forType: LastWebEntitlementsFetchDate.self)

      // TODO: Maybe include status here
      let completeEvent = InternalSuperwallEvent.Redemption(state: .complete)
      await Superwall.shared.track(completeEvent)

      if let paywallVc = Superwall.shared.paywallViewController {
        if response.entitlements.isEmpty {
          await paywallVc.presentAlert(
            title: Superwall.shared.options.paywalls.restoreFailed.title,
            message: Superwall.shared.options.paywalls.restoreFailed.message,
            closeActionTitle: Superwall.shared.options.paywalls.restoreFailed.closeButtonTitle
          )
        } else {
          // TODO: - What if using getPaywall?
          let trackedEvent = await InternalSuperwallEvent.Restore(
            state: .complete,
            paywallInfo: paywallVc.info
          )
          await Superwall.shared.track(trackedEvent)

          await paywallVc.webView.messageHandler.handle(.transactionRestore)

          let superwallOptions = factory.makeSuperwallOptions()
          if superwallOptions.paywalls.automaticallyDismiss {
            await Superwall.shared.dismiss(paywallVc, result: .restored)
          }
        }
      }

      storage.save(response, forType: LatestRedeemResponse.self)

      let allEntitlements = Array(Superwall.shared.entitlements.active.union(response.entitlements))
      let customerInfo = CustomerInfo(
        entitlements: allEntitlements,
        redemptions: response.results
      )

      // Either sets the subscription status internally using
      // automatic purchase controller or calls the external
      // purchase controller.
      await purchaseController.offDeviceSubscriptionsDidChange(customerInfo: customerInfo)

      // TODO: Could this intefere with an unknown status of local entitlements if this is set before device entitlements set?

      // Call the delegate if user try to redeem a code
      if case let .code(code) = type {
        if let codeResult = response.results.first(where: { $0.code == code }) {
          await delegate.didRedeemCode(
            customerInfo: customerInfo,
            result: codeResult
          )
        }
      }
    } catch {
      let event = InternalSuperwallEvent.Redemption(state: .fail)
      await Superwall.shared.track(event)

      // Call the delegate if user try to redeem a code
      if case let .code(code) = type {
        let entitlements = Array(Superwall.shared.entitlements.active)

        var redemptions = latestRedeemResponse?.results ?? []
        let errorResult = RedemptionResult.error(
          code: code,
          error: RedemptionResult.ErrorInfo(
            message: error.localizedDescription
          )
        )
        redemptions.append(errorResult)

        let customerInfo = CustomerInfo(
          entitlements: entitlements,
          redemptions: redemptions
        )

        await purchaseController.offDeviceSubscriptionsDidChange(customerInfo: customerInfo)

        await delegate.didRedeemCode(
          customerInfo: customerInfo,
          result: errorResult
        )
      }

      Logger.debug(
        logLevel: .error,
        scope: .webEntitlements,
        message: "Failed to redeem purchase token",
        info: [:]
      )
    }
  }

  @objc
  nonisolated private func handleAppForeground() {
    Task {
      await pollWebEntitlements()
    }
  }

  func pollWebEntitlements(config: Config? = nil) async {
    guard config != nil || factory.makeHasConfig() else {
      return
    }
    guard let entitlementsMaxAge = config?.web2appConfig?.entitlementsMaxAge ?? factory.makeEntitlementsMaxAge() else {
      return
    }

    if let lastFetchedWebEntitlementsAt = storage.get(LastWebEntitlementsFetchDate.self) {
      let timeElapsed = Date().timeIntervalSince(lastFetchedWebEntitlementsAt)
      guard timeElapsed > entitlementsMaxAge else {
        return
      }
    }

    do {
      let entitlements = try await network.redeemEntitlements(
        appUserId: factory.makeAppUserId(),
        deviceId: factory.makeDeviceId()
      )
      var redemptions: [RedemptionResult] = []

      // Update the latest redeem response with the entitlements.
      if var latestRedeemResponse = storage.get(LatestRedeemResponse.self) {
        latestRedeemResponse.entitlements = entitlements
        storage.save(latestRedeemResponse, forType: LatestRedeemResponse.self)
        redemptions = latestRedeemResponse.results
      }

      storage.save(Date(), forType: LastWebEntitlementsFetchDate.self)

      let allEntitlements = entitlements.union(entitlementsInfo.active)

      let customerInfo = CustomerInfo(
        entitlements: Array(allEntitlements),
        redemptions: redemptions
      )
      await purchaseController.offDeviceSubscriptionsDidChange(customerInfo: customerInfo)
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
