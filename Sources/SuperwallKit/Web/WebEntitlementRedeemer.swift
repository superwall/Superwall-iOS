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
  private var superwall: Superwall?

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
    factory: WebEntitlementFactory & OptionsFactory,
    superwall: Superwall? = nil
  ) {
    self.network = network
    self.storage = storage
    self.entitlementsInfo = entitlementsInfo
    self.delegate = delegate
    self.purchaseController = purchaseController
    self.factory = factory
    self.superwall = superwall

    // Observe when the app enters the foreground
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }

  func redeem(_ type: RedeemType) async {
    let superwall = superwall ?? Superwall.shared
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

      if let paywallVc = superwall.paywallViewController {
        let trackedEvent = await InternalSuperwallEvent.Restore(
          state: .start,
          paywallInfo: paywallVc.info
        )
        await superwall.track(trackedEvent)
      }

      let startEvent = InternalSuperwallEvent.Redemption(state: .start)
      await superwall.track(startEvent)

      switch type {
      case .code:
        await delegate.willRedeemLink()
      case .existingCodes:
        break
      }

      let response = try await network.redeemEntitlements(request: request)

      storage.save(Date(), forType: LastWebEntitlementsFetchDate.self)

      let completeEvent = InternalSuperwallEvent.Redemption(state: .complete)
      await superwall.track(completeEvent)

      if let paywallVc = superwall.paywallViewController {
        if response.entitlements.isEmpty {
          await trackRestorationFailure(
            paywallViewController: paywallVc,
            message: "Failed to restore subscriptions from the web",
            superwall: superwall
          )
        } else {
          let trackedEvent = await InternalSuperwallEvent.Restore(
            state: .complete,
            paywallInfo: paywallVc.info
          )
          await superwall.track(trackedEvent)

          await paywallVc.webView.messageHandler.handle(.restoreComplete)

          let superwallOptions = factory.makeSuperwallOptions()
          if superwallOptions.paywalls.automaticallyDismiss {
            await superwall.dismiss(paywallVc, result: .restored)
          }
        }
      }

      storage.save(response, forType: LatestRedeemResponse.self)

      // Sets the subscription status internally if no external PurchaseController
      let deviceEntitlements = entitlementsInfo.activeDeviceEntitlements
      let allEntitlements = deviceEntitlements.union(response.entitlements)

      await superwall.internallySetSubscriptionStatus(
        to: .active(allEntitlements),
        superwall: superwall
      )

      // Call the delegate if user try to redeem a code
      if case let .code(code) = type {
        if let codeResult = response.results.first(where: { $0.code == code }) {
          await delegate.didRedeemLink(result: codeResult)
        }
      }
    } catch {
      let event = InternalSuperwallEvent.Redemption(state: .fail)
      await superwall.track(event)

      if let paywallVc = superwall.paywallViewController {
        await trackRestorationFailure(
          paywallViewController: paywallVc,
          message: error.localizedDescription,
          superwall: superwall
        )
      }

      // Call the delegate if user try to redeem a code
      if case let .code(code) = type {
        var redemptions = latestRedeemResponse?.results ?? []
        let errorResult = RedemptionResult.error(
          code: code,
          error: RedemptionResult.ErrorInfo(
            message: error.localizedDescription
          )
        )
        redemptions.append(errorResult)

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
      await pollWebEntitlements()
    }
  }

  func pollWebEntitlements(config: Config? = nil) async {
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
