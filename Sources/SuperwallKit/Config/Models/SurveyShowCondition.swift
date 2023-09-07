//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/09/2023.
//

import Foundation

/// An enum whose cases indicate when a survey should
/// show.
@objc(SWKSurveyShowCondition)
public enum SurveyShowCondition: Int, Decodable {
  /// Shows the survey when the user manually closes the paywall.
  case onManualClose

  /// Shows the survey after the user purchases.
  case onPurchase

  enum CodingKeys: String, CodingKey {
    case onManualClose = "ON_MANUAL_CLOSE"
    case onPurchase = "ON_PURCHASE"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    let reason = CodingKeys(rawValue: rawValue) ?? .onManualClose
    switch reason {
    case .onManualClose:
      self = .onManualClose
    case .onPurchase:
      self = .onPurchase
    }
  }
}
