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
  enum PollRedemptionStatus: String, Codable {
    case pending
    case failed
    case complete
  }

  var results: [RedemptionResult]
  var customerInfo: CustomerInfo
  var status: PollRedemptionStatus?

  private enum CodingKeys: String, CodingKey {
    case results = "codes"
    case customerInfo
    case status
  }

  var allCodes: Set<Redeemable> {
    return Set(results.map {
      Redeemable(code: $0.code, isFirstRedemption: false)
    })
  }

  init(
    results: [RedemptionResult],
    customerInfo: CustomerInfo,
    status: PollRedemptionStatus? = nil
  ) {
    self.results = results
    self.customerInfo = customerInfo
    self.status = status
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.results = try container.decode([RedemptionResult].self, forKey: .results)
    self.customerInfo = try container.decodeIfPresent(CustomerInfo.self, forKey: .customerInfo) ?? .blank()
    self.status = try container.decodeIfPresent(PollRedemptionStatus.self, forKey: .status)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(results, forKey: .results)
    try container.encode(customerInfo, forKey: .customerInfo)
    try container.encodeIfPresent(status, forKey: .status)
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
