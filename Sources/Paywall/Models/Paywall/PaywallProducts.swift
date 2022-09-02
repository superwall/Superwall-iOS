//
//  File.swift
//  
//
//  Created by Yusuf Tör on 31/08/2022.
//

import Foundation
import StoreKit

/// Defines primary, secondary and tertiary products to be used on the paywall.
///
/// Pass an instance of this to ``Paywall/Paywall/trigger(event:params:on:products:ignoreSubscriptionStatus:presentationStyleOverride:onSkip:onPresent:onDismiss:)`` to replace your remotely defined products.
@objc public class PaywallProducts: NSObject {
  var primary: SKProduct?
  var secondary: SKProduct?
  var tertiary: SKProduct?

  private override init() {}

  /// Define one or more products to be substituted into the paywall.
  ///
  /// - parameters:
  ///   - primary: The primary product for your paywall.
  ///   - secondary: The secondary product for your paywall.
  ///   - tertiary: The tertiary product for your paywall.
  public init(
    primary: SKProduct? = nil,
    secondary: SKProduct? = nil,
    tertiary: SKProduct? = nil
  ) {
    self.primary = primary
    self.secondary = secondary
    self.tertiary = tertiary
  }
}
