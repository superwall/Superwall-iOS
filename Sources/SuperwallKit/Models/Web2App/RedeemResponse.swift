//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/03/2025.
//

import Foundation

public struct RedeemResponse: Codable {
  let results: [RedemptionResult]
  let entitlements: Set<Entitlement>

  private enum CodingKeys: String, CodingKey {
    case results = "codes"
    case entitlements
  }

  var allCodes: Set<Redeemable> {
    return Set(results.map {
      Redeemable(code: $0.code, isFirstRedemption: false)
    })
  }
}
