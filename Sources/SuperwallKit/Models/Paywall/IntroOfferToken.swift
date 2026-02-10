//
//  IntroOfferToken.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 21/05/2025.
//

import Foundation

struct IntroOfferTokenWrapper: Codable {
  let tokensByProductId: [String: IntroOfferToken]

  enum CodingKeys: String, CodingKey {
    case tokensByProductId = "tokens"
  }
}

/// A token used to override Apple's automatic intro offer eligibility determination.
///
/// Use this token with StoreKit 2's `.introductoryOfferEligibility(compactJWS:)`
/// purchase option to apply intro offer eligibility on iOS 18.2+.
public struct IntroOfferToken: Codable, Sendable {
  /// The JWT token string to pass to StoreKit.
  public let token: String

  /// The expiration date of the token.
  public let expiry: Date

  enum CodingKeys: String, CodingKey {
    case token
    case expiry = "expiresAt"
  }

  init(token: String, expiry: Date) {
    self.token = token
    self.expiry = expiry
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    token = try container.decode(String.self, forKey: .token)

    let timestamp = try container.decode(Milliseconds.self, forKey: .expiry)
    expiry = Date(timeIntervalSince1970: timestamp / 1000)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(token, forKey: .token)
    try container.encode(expiry.timeIntervalSince1970 * 1000, forKey: .expiry)
  }
}
