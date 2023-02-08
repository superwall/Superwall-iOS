//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/02/2023.
//

import Foundation

/// An enum representing the subscription status of the user.
@objc(SWKSubscriptionStatus)
public enum SubscriptionStatus: Int {
  /// The user has an active subscription.
  case active

  /// The user doesn't have an active subscription.
  case inactive

  /// The subscription status is unknown.
  case unknown
}
