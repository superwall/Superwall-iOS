//
//  IntroOfferEligibilityRequest.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 21/05/2025.
//

struct IntroOfferEligibilityRequest: Codable {
  let eligible: Bool
  let productIds: [String]
  let appTransactionId: String
}
