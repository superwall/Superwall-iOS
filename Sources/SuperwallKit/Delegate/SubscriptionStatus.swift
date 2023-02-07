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

extension Superwall {
  /// Sets the user's subscription status.
  ///
  /// You must implement this method if you're returning a ``SubscriptionController``
  /// in the ``SuperwallDelegate``. Do not use this method if you're letting Superwall
  /// handle subscription-related logic for you.
  ///
  /// Every time the user's subscription status is updated, you need to tell Superwall using this
  /// method.
  ///
  /// If the subscription status is set to `.unknown`, Superwall will delay presentation of paywalls
  /// until the status changes to `.active` or `.inactive`.
  ///
  /// To learn more, see <doc:AdvancedConfiguration>.
  ///
  /// - Parameters:
  ///   - subscriptionStatus: An enum representing the subscription status of the user:
  ///   `.unknown`, `.active`, or `.inactive`.
  @objc public func setSubscriptionStatus(to subscriptionStatus: SubscriptionStatus) {
    // Prevent users accidentally setting the subscription status
    // without a subscription controller.
    guard dependencyContainer.delegateAdapter.hasSubscriptionController else {
      return
    }

    setInternalSubscriptionStatus(to: subscriptionStatus)
  }

  /// Sets the internal subscription status.
  func setInternalSubscriptionStatus(to subscriptionStatus: SubscriptionStatus) {
    // Send out ObservableObject willChange for SwiftUI views
    objectWillChange.send()

    // Set the status.
    internalSubscriptionStatus.send(subscriptionStatus)
  }
}
