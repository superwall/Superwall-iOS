//
//  IntroOfferToken.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 21/05/2025.
//

import Foundation

struct IntroOfferTokenWrapper: Codable {
  let tokensByProductId: [String: IntroOfferToken]
}

struct IntroOfferToken: Codable {
  let token: String
  let expiry: Date
}
