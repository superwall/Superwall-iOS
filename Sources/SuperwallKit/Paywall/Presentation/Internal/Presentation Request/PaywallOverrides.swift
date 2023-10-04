//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/09/2022.
//

import Foundation

/// Override the default behavior and products of a paywall.
///
/// Provide an instance of this to ``Superwall/getPaywall(forEvent:params:paywallOverrides:delegate:)``.
@objc(SWKPaywallOverrides)
@objcMembers
public final class PaywallOverrides: NSObject, Sendable {
  /// Defines the products to override on the paywall.
  ///
  /// You can override one or more products of your choosing.
  public let products: PaywallProducts?

  /// Set this to `true` to always show the paywall, regardless of whether the user has an active subscription or not.
  public let ignoreSubscriptionStatus: Bool

  /// Sets a custom presentation style for the paywall.
  public let presentationStyle: PaywallPresentationStyle

  /// Override the default behavior and products of a paywall.
  ///
  /// Provide an instance of this to ``Superwall/getPaywall(forEvent:params:paywallOverrides:delegate:)``.
  ///
  /// - parameters:
  ///   - products: A ``PaywallProducts`` object defining the products to override on the paywall.
  ///   - ignoreSubscriptionStatus: Set this to `true` to always show the paywall, regardless of whether the user has an active subscription or not.
  ///   - presentationStyleOverride: A ``PaywallPresentationStyle`` enum that specifies the presentation style for the paywall.
  public init(
    products: PaywallProducts? = nil,
    ignoreSubscriptionStatus: Bool = false,
    presentationStyleOverride: PaywallPresentationStyle = .none
  ) {
    self.products = products
    self.ignoreSubscriptionStatus = ignoreSubscriptionStatus
    self.presentationStyle = presentationStyleOverride
  }

  /// Override the default behavior and products of a paywall.
  ///
  /// Provide an instance of this to ``Superwall/getPaywall(forEvent:params:paywallOverrides:delegate:)``.
  ///
  /// - parameters:
  ///   - products: A ``PaywallProducts`` object defining the products to override on the paywall.
  @available(swift, obsoleted: 1.0)
  public init(products: PaywallProducts?) {
    self.products = products
    self.ignoreSubscriptionStatus = false
    self.presentationStyle = .none
  }

  /// Override the default behavior and products of a paywall.
  ///
  /// Provide an instance of this to ``Superwall/getPaywall(forEvent:params:paywallOverrides:delegate:)``.
  ///
  /// - parameters:
  ///   - products: A ``PaywallProducts`` object defining the products to override on the paywall.
  ///   - ignoreSubscriptionStatus: Set this to `true` to always show the paywall, regardless of whether the user has an active subscription or not.
  @available(swift, obsoleted: 1.0)
  public init(
    products: PaywallProducts?,
    ignoreSubscriptionStatus: Bool = false
  ) {
    self.products = products
    self.ignoreSubscriptionStatus = ignoreSubscriptionStatus
    self.presentationStyle = .none
  }
}
