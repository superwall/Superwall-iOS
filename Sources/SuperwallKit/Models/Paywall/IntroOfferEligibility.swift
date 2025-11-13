//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 20/05/2025.
//

import Foundation

/// An enum whose cases indicate the user's eligibility for introductory offers on the paywall.
@objc(SWKIntroOfferEligibility)
public enum IntroOfferEligibility: Int, Codable, CustomStringConvertible, Sendable {
  /// Allows a user to always claim a free trial.
  case eligible

  /// Always blocks the user from claiming a free trial.
  case ineligible

  /// Lets StoreKit decide eligibility.
  case automatic

  enum CodingKeys: String, CodingKey {
    case eligible = "ALWAYS_ELIGIBLE"
    case ineligible = "ALWAYS_INELIGIBLE"
    case automatic = "AUTOMATIC"
  }

  public var description: String {
    switch self {
    case .eligible:
      return "ALWAYS_ELIGIBLE"
    case .ineligible:
      return "ALWAYS_INELIGIBLE"
    case .automatic:
      return "AUTOMATIC"
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    let gatingType = CodingKeys(rawValue: rawValue) ?? .automatic
    switch gatingType {
    case .automatic:
      self = .automatic
    case .eligible:
      self = .eligible
    case .ineligible:
      self = .ineligible
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }
}
