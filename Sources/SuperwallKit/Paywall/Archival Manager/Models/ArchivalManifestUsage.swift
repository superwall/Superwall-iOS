//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/05/2024.
//

import Foundation

/// An enum whose cases specify whether the manifest should be used.
enum ArchivalManifestUsage: Codable {
  /// Always use the manifest
  case always

  /// Never use the manifest
  case never

  /// Only use the manifest if it's available on paywall open.
  case ifAvailableOnPaywallOpen

  enum CodingKeys: String, CodingKey {
    case always = "ALWAYS"
    case never = "NEVER"
    case ifAvailableOnPaywallOpen = "IF_AVAILABLE_ON_PAYWALL_OPEN"
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    let gatingType = CodingKeys(rawValue: rawValue) ?? .ifAvailableOnPaywallOpen
    switch gatingType {
    case .always:
      self = .always
    case .never:
      self = .never
    case .ifAvailableOnPaywallOpen:
      self = .ifAvailableOnPaywallOpen
    }
  }
}
