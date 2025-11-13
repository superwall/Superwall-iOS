//
//  IntroOfferEligibilityRequest.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 21/05/2025.
//

struct IntroOfferEligibilityRequest: Codable {
  struct Product: Codable {
    let productId: String
    let transactionId: String
  }

  let allowIntroductoryOffer: Bool
  let products: [Product]
}
