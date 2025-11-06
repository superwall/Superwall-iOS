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
  var customerInfo: CustomerInfo

  private enum CodingKeys: String, CodingKey {
    case results = "codes"
    case customerInfo
  }

  var allCodes: Set<Redeemable> {
    return Set(results.map {
      Redeemable(code: $0.code, isFirstRedemption: false)
    })
  }

  init(
    results: [RedemptionResult],
    customerInfo: CustomerInfo
  ) {
    self.results = results
    self.customerInfo = customerInfo
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.results = try container.decode([RedemptionResult].self, forKey: .results)
    self.customerInfo = try container.decodeIfPresent(CustomerInfo.self, forKey: .customerInfo) ?? .blank()
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(results, forKey: .results)
    try container.encode(customerInfo, forKey: .customerInfo)
  }
}

extension RedeemResponse: Stubbable {
  static func stub() -> RedeemResponse {
    return .init(
      results: [],
      customerInfo: CustomerInfo.stub()
    )
  }
}
