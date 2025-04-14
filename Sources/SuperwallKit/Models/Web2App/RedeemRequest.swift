//
//  RedeemRequest.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 12/03/2025.
//

struct RedeemRequest: Encodable {
  let deviceId: String
  let appUserId: String?
  let aliasId: String
  let codes: Set<Redeemable>
  let receipts: [TransactionReceipt]
}

struct TransactionReceipt: Encodable {
  let type = "IOS"
  let jwsRepresentation: String
}
