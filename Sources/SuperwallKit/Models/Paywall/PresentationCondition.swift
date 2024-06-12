//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//

import Foundation

/// The condition for when a paywall should present.
@objc(SWKPresentationCondition)
public enum PresentationCondition: Int, Decodable {
  /// The paywall will always present, regardless of subscription status.
  case always

  /// The paywall will only present if the ``Superwall/subscriptionStatus`` is ``SubscriptionStatus/inactive``.
  case checkUserSubscription

  enum CodingKeys: String, CodingKey {
    case always = "ALWAYS"
    case checkUserSubscription = "CHECK_USER_SUBSCRIPTION"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    let type = CodingKeys(rawValue: rawValue)
    switch type {
    case .always:
      self = .always
    case .checkUserSubscription:
      self = .checkUserSubscription
    case nil:
      self = .checkUserSubscription
    }
  }
}
