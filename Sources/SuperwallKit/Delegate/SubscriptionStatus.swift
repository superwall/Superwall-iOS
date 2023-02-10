//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/02/2023.
//

import Foundation
import UIKit
/// A class representing the subscription status of the user.
@objc(SWKSubscriptionStatus)
@objcMembers
public final class SubscriptionStatus: NSObject, Codable {
  enum Value: CustomStringConvertible, Codable {
    /// The user has an active subscription.
    case active

    /// The user doesn't have an active subscription.
    case inactive

    /// The subscription status is unknown.
    case unknown

    var description: String {
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
  let value: Value

  enum CodingKeys: CodingKey {
    case value
  }

  init(_ value: Value) {
    self.value = value
  }

  public override func isEqual(_ object: Any?) -> Bool {
    if let status = object as? SubscriptionStatus {
      return status.value == value
    }
    return false
  }

    /// The user has an active subscription.
  public static let active = SubscriptionStatus(.active)

  /// The user doesn't have an active subscription.
  public static let inactive = SubscriptionStatus(.inactive)

  /// The subscription status is unknown.
  public static let unknown = SubscriptionStatus(.unknown)
}

