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

  init(
    network: Network,
    storage: Storage,
    entitlementsInfo: EntitlementsInfo,
    factory: WebEntitlementFactory
  ) {
    self.network = network
    self.storage = storage
    self.entitlementsInfo = entitlementsInfo
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
    do {
      // TODO: Moved away from having codes array and latest redeem response. Now just use latest redeem response. Need a way to get the array of codes there.
      var codes = storage.get(LatestRedeemResponse.self)
      var isFirstRedemption = true

      // If we have codes, isFirstRedemption is false if we already have the code
      if !codes.isEmpty {
        isFirstRedemption = !codes.contains(where: { $0.code == code })
      }

      // Save code to storage along with others
      let redeemable = Redeemable(
        code: code,
        isFirstRedemption: isFirstRedemption
      )
      codes.append(redeemable)

      let request = RedeemRequest(
        deviceId: factory.makeDeviceId(),
        appUserId: factory.makeAppUserId(),
        aliasId: factory.makeAliasId(),
        codes: codes
      )

      let startEvent = InternalSuperwallEvent.Redemption(state: .start)
      await Superwall.shared.track(startEvent)

      let response = try await network.redeemEntitlements(request: request)

      // TODO: Maybe include status here
      let completeEvent = InternalSuperwallEvent.Redemption(state: .complete)
      await Superwall.shared.track(completeEvent)

      storage.save(response, forType: LatestRedeemResponse.self)

      let webEntitlements = response.entitlements
      if !webEntitlements.isEmpty {
        entitlementsInfo.mergeWebEntitlements(webEntitlements)
      }
    } catch {
      let event = InternalSuperwallEvent.Redemption(state: .fail)
      await Superwall.shared.track(event)

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
