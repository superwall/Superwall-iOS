//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/03/2025.
//
// swiftlint:disable function_body_length

import UIKit
import Foundation

final class WebEntitlementRedeemer {
  private let network: Network
  private let storage: Storage
  private let entitlementsInfo: EntitlementsInfo
  private let delegate: SuperwallDelegateAdapter
  private let purchaseController: PurchaseController
  private let factory: WebEntitlementFactory

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
    factory: WebEntitlementFactory
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

      let startEvent = InternalSuperwallEvent.Redemption(state: .start)
      await Superwall.shared.track(startEvent)

      let response = try await network.redeemEntitlements(request: request)

      storage.save(Date(), forType: LastWebEntitlementsFetchDate.self)

      // TODO: Maybe include status here
      let completeEvent = InternalSuperwallEvent.Redemption(state: .complete)
      await Superwall.shared.track(completeEvent)

      storage.save(response, forType: LatestRedeemResponse.self)

      let entitlements = Array(Superwall.shared.entitlements.active)
      let customerInfo = CustomerInfo(
        entitlements: entitlements,
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
  private func handleAppForeground() {
    Task {
      await pollWebEntitlements()
    }
  }

  func pollWebEntitlements() async {
    guard factory.makeHasConfig() else {
      return
    }

    if let lastFetchedWebEntitlementsAt = storage.get(LastWebEntitlementsFetchDate.self),
      let entitlementsMaxAge = factory.makeEntitlementsMaxAge() {
      let timeElapsed = Date().timeIntervalSince(lastFetchedWebEntitlementsAt)
      guard timeElapsed > entitlementsMaxAge else {
        return
      }
    }

    let id: String

    if let appUserId = factory.makeAppUserId() {
      id = appUserId
    } else {
      id = factory.makeDeviceId()
    }

    do {
      let entitlements = try await network.redeemEntitlements(appUserIdOrDeviceId: id)
      var redemptions: [RedemptionResult] = []

      // Update the latest redeem response with the entitlements.
      if var latestRedeemResponse = storage.get(LatestRedeemResponse.self) {
        latestRedeemResponse.entitlements = entitlements
        storage.save(latestRedeemResponse, forType: LatestRedeemResponse.self)
        redemptions = latestRedeemResponse.results
      }

      storage.save(Date(), forType: LastWebEntitlementsFetchDate.self)

      let customerInfo = CustomerInfo(
        entitlements: Array(entitlements),
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
