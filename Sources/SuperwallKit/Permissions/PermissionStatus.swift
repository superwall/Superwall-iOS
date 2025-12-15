//
//  PermissionStatus.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import Foundation

/// Status of a permission request.
/// Maps to the paywall schema permission_status values.
public enum PermissionStatus: String, Decodable {
  case granted
  case denied
  case unsupported

  /// Create a PermissionStatus from a raw string value
  /// - Parameter raw: The permission status string (e.g., "granted")
  /// - Returns: The corresponding PermissionStatus or nil if not found
  static func fromRaw(_ raw: String) -> PermissionStatus? {
    return PermissionStatus(rawValue: raw)
  }
}
