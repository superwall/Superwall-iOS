//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 25/10/2024.
//

import Foundation

/// An enum representing the subscription status of the user.
public enum SubscriptionStatus: Equatable, Codable {
  /// The subscription status is unknown.
  case unknown

  /// The user doesn't have an active subscription.
  case inactive

  /// The user has an active subscription with a `Set` of one or more entitlements.
  case active(Set<Entitlement>)

  public static func == (lhs: SubscriptionStatus, rhs: SubscriptionStatus) -> Bool {
    switch (lhs, rhs) {
    case (.unknown, .unknown), (.inactive, .inactive):
      return true
    case let (.active(lhsSet), .active(rhsSet)):
      return lhsSet == rhsSet
    default:
      return false
    }
  }

  /// A convenience boolean indicating whether the subscription status is active.
  ///
  /// Returns `true` only if there is at least one active entitlement.
  public var isActive: Bool {
    switch self {
    case .active(let entitlements):
      return entitlements.contains { $0.isActive }
    default:
      return false
    }
  }

  func toObjc() -> SubscriptionStatusObjc {
    switch self {
    case .active(let entitlements):
      // Only return .active if there's at least one active entitlement
      return entitlements.contains { $0.isActive } ? .active : .inactive
    case .inactive:
      return .inactive
    case .unknown:
      return .unknown
    }
  }
}

// MARK: - CustomStringConvertible
extension SubscriptionStatus: CustomStringConvertible {
  public var description: String {
    switch self {
    case .active(let entitlements):
      // Only show as ACTIVE if there's at least one active entitlement
      return entitlements.contains { $0.isActive } ? "ACTIVE" : "INACTIVE"
    case .inactive:
      return "INACTIVE"
    case .unknown:
      return "UNKNOWN"
    }
  }
}

/// An enum representing the entitlement status of the user.
@objc(SWKSubscriptionStatus)
public enum SubscriptionStatusObjc: Int {
  /// The subscription status is unknown.
  case unknown

  /// The user doesn't have an active subscription.
  case inactive

  /// The user has an active subscription.
  case active
}

// MARK: - CustomStringConvertible
extension SubscriptionStatusObjc: CustomStringConvertible {
  public var description: String {
    switch self {
    case .active:
      return "ACTIVE"
    case .inactive:
      return "INACTIVE"
    case .unknown:
      return "UNKNOWN"
    }
  }
}
