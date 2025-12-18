//
//  PermissionType.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import Foundation

/// Permission types that can be requested from the host app.
/// Maps to the paywall schema permission_type values.
public enum PermissionType: String, Decodable {
  case notification
  case location
  // swiftlint:disable:next identifier_name
  case background_location
  // swiftlint:disable:next identifier_name
  case read_images
  case contacts
  case camera

  /// Create a PermissionType from a raw string value
  /// - Parameter raw: The permission type string (e.g., "notification")
  /// - Returns: The corresponding PermissionType or nil if not found
  static func fromRaw(_ raw: String) -> PermissionType? {
    return PermissionType(rawValue: raw)
  }
}
