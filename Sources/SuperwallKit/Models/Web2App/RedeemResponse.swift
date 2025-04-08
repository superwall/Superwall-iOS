//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/03/2025.
//

import Foundation

/// An object return from the server acting as a source of truth for the redeemed codes
/// and web entitlements.
struct RedeemResponse: Codable {
  var results: [RedemptionResult]
  var entitlements: Set<Entitlement>

  private enum CodingKeys: String, CodingKey {
    case results = "codes"
    case entitlements
  }

  var allCodes: Set<Redeemable> {
    return Set(results.map {
      Redeemable(code: $0.code, isFirstRedemption: false)
    })
  }

  init(
    results: [RedemptionResult],
    entitlements: Set<Entitlement>
  ) {
    self.results = results
    self.entitlements = entitlements
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.results = try container.decode([RedemptionResult].self, forKey: .results)
    self.entitlements = try container.decode(Set<Entitlement>.self, forKey: .entitlements)
  }
}

extension RedeemResponse: Stubbable {
  static func stub() -> RedeemResponse {
    return .init(
      results: [],
      entitlements: []
    )
  }
}
