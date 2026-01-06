//
//  PermissionType.swift
//  SuperwallKit
//
//  Created by Superwall on 2025.
//

import Foundation

/// Permission types that can be requested from the host app.
/// Maps to the paywall schema permission_type values.
enum PermissionType: String, Decodable {
  case notification
  case location
  case backgroundLocation = "background_location"
  case readImages = "read_images"
  case contacts
  case camera
}
