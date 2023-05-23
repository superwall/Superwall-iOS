//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/05/2023.
//

import Foundation

/// An enum whose cases indicate whether caching of the paywall is enabled or not.
enum OnDeviceCaching: Decodable {
  case enabled
  case disabled

  enum CodingKeys: String, CodingKey {
    case enabled = "ENABLED"
    case disabled = "DISABLED"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    let caching = CodingKeys(rawValue: rawValue) ?? .enabled
    switch caching {
    case .enabled:
      self = .enabled
    case .disabled:
      self = .disabled
    }
  }
}
