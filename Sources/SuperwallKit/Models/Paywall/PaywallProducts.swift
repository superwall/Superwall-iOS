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
/// Pass an instance of this to ``SuperwallKit/Superwall/track(event:params:paywallOverrides:paywallHandler:)`` to replace your remotely defined products.
@objc(SWKPaywallProducts)
public class PaywallProducts: NSObject {
  /// The primary product for the paywall.
  var primary: SKProduct?

  /// The secondary product for the paywall.
  var secondary: SKProduct?

  /// The tertiary product for the paywall.
  var tertiary: SKProduct?

  var ids: [String] = []

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

    var ids: [String] = []
    if let primary = primary {
      ids.append(primary.productIdentifier)
    }
    if let secondary = secondary {
      ids.append(secondary.productIdentifier)
    }
    if let tertiary = tertiary {
      ids.append(tertiary.productIdentifier)
    }
    self.ids = ids
  }
}
