//
//  Redeemable.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/03/2025.
//

struct Redeemable: Codable {
  let code: String
  let isFirstRedemption: Bool

  private enum CodingKeys: String, CodingKey {
    case code
    case isFirstRedemption = "firstRedemption"
  }
}
