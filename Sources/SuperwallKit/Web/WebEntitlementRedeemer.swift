//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/03/2025.
//

import Foundation

final class WebEntitlementRedeemer {
  private let network: Network
  private let storage: Storage
  private let entitlementsInfo: EntitlementsInfo
  private let factory: WebEntitlementFactory
  private let delegate: SuperwallDelegateAdapter

  init(
    network: Network,
    storage: Storage,
    entitlementsInfo: EntitlementsInfo,
    delegate: SuperwallDelegateAdapter,
    factory: WebEntitlementFactory
  ) {
    self.network = network
    self.storage = storage
    self.entitlementsInfo = entitlementsInfo
    self.delegate = delegate
    self.factory = factory

//    Task {
//      await checkForReferral()
//    }
  }

//  func checkForReferral() async {
//    do {
//      let referralCodes = try await deepLinkReferrer.checkForReferral()
//      await redeem(codes: referralCodes)
//    } catch {
//      // TODO: Alter this.
//      print("Error checking for referral: \(error)")
//    }
//  }

  func redeem(code: String) async {
    var latestRedeemResponse = storage.get(LatestRedeemResponse.self)

    do {
      var allCodes = latestRedeemResponse?.allCodes ?? []
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

      let request = RedeemRequest(
        deviceId: factory.makeDeviceId(),
        appUserId: factory.makeAppUserId(),
        aliasId: factory.makeAliasId(),
        codes: allCodes
      )

      let startEvent = InternalSuperwallEvent.Redemption(state: .start)
      await Superwall.shared.track(startEvent)

      let response = try await network.redeemEntitlements(request: request)

      // TODO: Maybe include status here
      let completeEvent = InternalSuperwallEvent.Redemption(state: .complete)
      await Superwall.shared.track(completeEvent)

      storage.save(response, forType: LatestRedeemResponse.self)

      // Merge web entitlements with local
      let webEntitlements = response.entitlements
      if !webEntitlements.isEmpty {
        entitlementsInfo.mergeWebEntitlements(webEntitlements)
      }

      // Call the delegate
      if let codeResult = response.results.first(where: { $0.code == code }) {
        let entitlements = Array(Superwall.shared.entitlements.active)
        let customerInfo = CustomerInfo(
          entitlements: entitlements,
          redemptions: response.results
        )

        await delegate.didRedeemCode(
          customerInfo: customerInfo,
          result: codeResult
        )
      }
    } catch {
      let event = InternalSuperwallEvent.Redemption(state: .fail)
      await Superwall.shared.track(event)

      let entitlements = Array(Superwall.shared.entitlements.active)

      var redemptions = latestRedeemResponse?.results ?? []
      let errorResult = RedemptionResult.error(
        code: code,
        error: RedemptionResult.ErrorInfo(message: error.localizedDescription)
      )
      redemptions.append(errorResult)

      let customerInfo = CustomerInfo(
        entitlements: entitlements,
        redemptions: redemptions
      )

      await delegate.didRedeemCode(
        customerInfo: customerInfo,
        result: errorResult
      )

      Logger.debug(
        logLevel: .error,
        scope: .webEntitlements,
        message: "Failed to redeem purchase token",
        info: [:]
      )
    }



    // TODO: Call delegate here
  }

  func checkForWebEntitlements() async throws -> Set<Entitlement> {
    let id: String

    if let appUserId = factory.makeAppUserId() {
      id = appUserId
    } else {
      id = factory.makeDeviceId()
    }

    return try await network.redeemEntitlements(appUserIdOrDeviceId: id)
  }
}
