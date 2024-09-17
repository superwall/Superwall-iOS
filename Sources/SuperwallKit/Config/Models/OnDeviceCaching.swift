//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/05/2023.
//

import Foundation

/// An enum whose cases indicate whether caching of the paywall is enabled or not.
enum OnDeviceCaching: Codable {
  case enabled
  case disabled

  enum CodingKeys: String, CodingKey {
    case enabled = "ENABLED"
    case disabled = "DISABLED"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    let caching = CodingKeys(rawValue: rawValue) ?? .disabled
    switch caching {
    case .enabled:
      self = .enabled
    case .disabled:
      self = .disabled
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    let rawValue: String
    switch self {
    case .enabled:
      rawValue = CodingKeys.enabled.rawValue
    case .disabled:
      rawValue = CodingKeys.disabled.rawValue
    }

    try container.encode(rawValue)
  }
}
