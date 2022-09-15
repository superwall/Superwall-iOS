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
/// Pass an instance of this to ``Paywall/Paywall/track(event:params:paywallOverrides:paywallState:)`` to replace your remotely defined products.
@objc public class PaywallProducts: NSObject {
  /// The primary product for the paywall.
  var primary: SKProduct?

  /// The secondary product for the paywall.
  var secondary: SKProduct?

  /// The tertiary product for the paywall.
  var tertiary: SKProduct?

  private override init() {}

  /// Define one or more products to be substituted into the paywall.
  ///
  /// - parameters:
  ///   - primary: The primary product for the paywall.
  ///   - secondary: The secondary product for the paywall.
  ///   - tertiary: The tertiary product for the paywall.
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
