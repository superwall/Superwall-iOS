//
//  RedeemRequest.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/03/2025.
//

struct RedeemRequest: Codable {
  let deviceId: String
  let appUserId: String?
  let aliasId: String
  let codes: [Redeemable]
}
