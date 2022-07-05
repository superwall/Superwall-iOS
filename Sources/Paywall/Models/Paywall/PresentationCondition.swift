//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//

import Foundation

enum PresentationCondition: String, Decodable {
  case always = "ALWAYS"
  case checkPrimarySubscription = "CHECK_PRIMARY_SUBSCRIPTION"

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(RawValue.self)
    self = PresentationCondition(rawValue: rawValue) ?? .checkPrimarySubscription
  }
}
