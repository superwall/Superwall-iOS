//
//  File.swift
//  
//
//  Created by Yusuf Tör on 31/08/2022.
//
// swiftlint:disable line_length

import Foundation
import StoreKit

/// Defines primary, secondary and tertiary products to be used on the paywall.
///
/// Pass an instance of this to ``PaywallOverrides/products`` to replace your remotely defined products.
@available(*, deprecated, message: "When overriding paywall products, pass a dictionary to productsByName in the PaywallOverrides object instead")
@objc(SWKPaywallProducts)
@objcMembers
public final class PaywallProducts: NSObject, Sendable {
  /// The primary product for the paywall.
  let primary: StoreProduct?

  /// The secondary product for the paywall.
  let secondary: StoreProduct?

  /// The tertiary product for the paywall.
  let tertiary: StoreProduct?

  ///  The product IDs.
  let ids: [String]

  private override init() {
    primary = nil
    secondary = nil
    tertiary = nil
    ids = []
  }

  /// Define one or more products to be substituted into the paywall.
  ///
  /// - parameters:
  ///   - primary: The primary product for the paywall.
  ///   - secondary: The secondary product for the paywall.
  ///   - tertiary: The tertiary product for the paywall.
  public init(
    primary: StoreProduct? = nil,
    secondary: StoreProduct? = nil,
    tertiary: StoreProduct? = nil
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
