//
//  PermissionHandling.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import Foundation

/// Protocol for handling user permission requests.
protocol PermissionHandling {
  /// Check the current status of a permission.
  /// - Parameter permission: The permission type to check
  /// - Returns: The current status of the permission
  func hasPermission(_ permission: PermissionType) async -> PermissionStatus

  /// Request a permission from the user.
  /// - Parameter permission: The permission type to request
  /// - Returns: The resulting status after the request
  func requestPermission(_ permission: PermissionType) async -> PermissionStatus
}
