//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/05/2024.
//

import Foundation

/// An enum whose cases specify whether the manifest should be used.
enum ArchiveManifestUsage: String, Codable {
  /// Always use the manifest
  case always = "ALWAYS"

  /// Never use the manifest
  case never = "NEVER"

  /// Only use the manifest if it's available on paywall open.
  case ifAvailableOnPaywallOpen = "IF_AVAILABLE_ON_PAYWALL_OPEN"
}
