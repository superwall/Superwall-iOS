//
//  PermissionStatus.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import Foundation

/// Status of a permission request.
/// Maps to the paywall schema permission_status values.
enum PermissionStatus: String, Decodable {
  case granted
  case denied
  case unsupported
}
