//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 25/10/2024.
//

import Foundation

/// An enum representing the entitlement status of the user.
public enum EntitlementStatus {
  /// The entitlement status is unknown.
  case unknown

  /// The user doesn't have any active entitlements.
  case noActiveEntitlements

  /// The user has active entitlements.
  case hasActiveEntitlements(Set<Entitlement>)

  func toObjc() -> EntitlementStatusObjc {
    switch self {
    case .hasActiveEntitlements:
      return .hasActiveEntitlements
    case .noActiveEntitlements:
      return .noActiveEntitlements
    case .unknown:
      return .unknown
    }
  }
}

// MARK: - CustomStringConvertible
extension EntitlementStatus: CustomStringConvertible {
  public var description: String {
    switch self {
    case .hasActiveEntitlements:
      return "HAS_ACTIVE_ENTITLEMENTS"
    case .noActiveEntitlements:
      return "NO_ACTIVE_ENTITLEMENTS"
    case .unknown:
      return "UNKNOWN"
    }
  }
}

/// An enum representing the entitlement status of the user.
@objc(SWKEntitlementStatus)
public enum EntitlementStatusObjc: Int {
  /// The entitlement status is unknown.
  case unknown

  /// The user doesn't have any active entitlements.
  case noActiveEntitlements

  /// The user has active entitlements.
  case hasActiveEntitlements
}
