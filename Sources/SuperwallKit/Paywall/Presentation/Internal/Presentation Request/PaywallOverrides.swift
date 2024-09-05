//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/09/2022.
//

import Foundation

/// Override the default behavior and products of a paywall.
///
/// Provide an instance of this to ``Superwall/getPaywall(forPlacement:params:paywallOverrides:delegate:)``.
@objc(SWKPaywallOverrides)
@objcMembers
public final class PaywallOverrides: NSObject, Sendable {
  /// Defines the products to override on the paywall.
  ///
  /// You can override one or more products of your choosing.
  @available(*, deprecated, renamed: "productsByName")
  public let products: PaywallProducts?

  /// Defines the products to override on the paywall by product name.
  ///
  /// You can override one or more products of your choosing. For example, this is how you would override the first and third product on the paywall:
  ///
  /// ```
  ///  PaywallOverrides(
  ///    products: [
  ///      "primary": firstProduct,
  ///      "tertiary": thirdProduct
  ///    ]
  ///  )
  /// ```
  ///
  /// This assumes that your products have the names "primary" and "tertiary" in the Paywall Editor.
  public let productsByName: [String: StoreProduct]

  /// Set this to `true` to always show the paywall, regardless of whether the user has an active subscription or not.
  public let ignoreSubscriptionStatus: Bool

  /// Sets a custom presentation style for the paywall.
  public let presentationStyle: PaywallPresentationStyle

  /// An internally used override. This overrides the feature gating behavior of the presented paywall.
  let featureGatingBehavior: FeatureGatingBehavior?

  /// Override the default behavior and products of a paywall.
  ///
  /// You can override one or more products of your choosing. For example, this is how you would override the first and third product on the paywall:
  ///
  /// ```
  ///  PaywallOverrides(
  ///    products: [
  ///      "primary": firstProduct,
  ///      "tertiary": thirdProduct
  ///    ]
  ///  )
  /// ```
  ///
  /// This assumes that your products have the names "primary" and "tertiary" in the Paywall Editor.
  ///
  /// Provide an instance of this to ``Superwall/getPaywall(forPlacement:params:paywallOverrides:delegate:)``.
  ///
  /// - parameters:
  ///   - productsByName: A dictionary mapping the name of the product to override on the paywall with a ``StoreProduct``.
  ///   - ignoreSubscriptionStatus: Set this to `true` to always show the paywall, regardless of whether the user has an active subscription or not.
  ///   - presentationStyleOverride: A ``PaywallPresentationStyle`` enum that specifies the presentation style for the paywall.
  public init(
    productsByName: [String: StoreProduct] = [:],
    ignoreSubscriptionStatus: Bool = false,
    presentationStyleOverride: PaywallPresentationStyle = .none
  ) {
    self.productsByName = productsByName
    self.products = Self.mapToPaywallProducts(productsByName)
    self.ignoreSubscriptionStatus = ignoreSubscriptionStatus
    self.presentationStyle = presentationStyleOverride
    self.featureGatingBehavior = nil
  }

  /// Internal init used for overriding the feature gating behavior for implicitly triggered paywalls.
  init(featureGatingBehavior: FeatureGatingBehavior) {
    self.productsByName = [:]
    self.products = nil
    self.ignoreSubscriptionStatus = false
    self.presentationStyle = .none
    self.featureGatingBehavior = featureGatingBehavior
  }

  /// Override the default behavior and products of a paywall.
  ///
  /// You can override one or more products of your choosing. For example, this is how you would override the first and third product on the paywall:
  ///
  /// ```
  ///  PaywallOverrides(
  ///    products: [
  ///      "primary": firstProduct,
  ///      "tertiary": thirdProduct
  ///    ]
  ///  )
  /// ```
  ///
  /// This assumes that your products have the names "primary" and "tertiary" in the Paywall Editor.
  ///
  /// Provide an instance of this to ``Superwall/getPaywall(forPlacement:params:paywallOverrides:delegate:)``.
  ///
  /// - parameters:
  ///   - productsByName: A dictionary mapping the name of the product to override on the paywall with a ``StoreProduct``.
  public init(
    productsByName: [String: StoreProduct]
  ) {
    self.productsByName = productsByName
    self.products = Self.mapToPaywallProducts(productsByName)
    self.ignoreSubscriptionStatus = false
    self.presentationStyle = .none
    self.featureGatingBehavior = nil
  }

  /// Override the default behavior and products of a paywall.
  ///
  /// You can override one or more products of your choosing. For example, this is how you would override the first and third product on the paywall:
  ///
  /// ```
  ///  PaywallOverrides(
  ///    products: [
  ///      "primary": firstProduct,
  ///      "tertiary": thirdProduct
  ///    ]
  ///  )
  /// ```
  ///
  /// This assumes that your products have the names "primary" and "tertiary" in the Paywall Editor.
  ///
  /// Provide an instance of this to ``Superwall/getPaywall(forPlacement:params:paywallOverrides:delegate:)``.
  ///
  /// - parameters:
  ///   - productsByName: A dictionary mapping the name of the product to override on the paywall with a ``StoreProduct``.
  public init(
    productsByName: [String: StoreProduct],
    ignoreSubscriptionStatus: Bool = false
  ) {
    self.productsByName = productsByName
    self.products = Self.mapToPaywallProducts(productsByName)
    self.ignoreSubscriptionStatus = ignoreSubscriptionStatus
    self.presentationStyle = .none
    self.featureGatingBehavior = nil
  }

  /// Override the default behavior and products of a paywall.
  ///
  /// Provide an instance of this to ``Superwall/getPaywall(forPlacement:params:paywallOverrides:delegate:)``.
  ///
  /// - parameters:
  ///   - products: A ``PaywallProducts`` object defining the products to override on the paywall.
  ///   - ignoreSubscriptionStatus: Set this to `true` to always show the paywall, regardless of whether the user has an active subscription or not.
  ///   - presentationStyleOverride: A ``PaywallPresentationStyle`` enum that specifies the presentation style for the paywall.
  @available(*, deprecated)
  public init(
    products: PaywallProducts? = nil,
    ignoreSubscriptionStatus: Bool = false,
    presentationStyleOverride: PaywallPresentationStyle = .none
  ) {
    self.productsByName = Self.mapFromPaywallProducts(products)
    self.products = products
    self.ignoreSubscriptionStatus = ignoreSubscriptionStatus
    self.presentationStyle = presentationStyleOverride
    self.featureGatingBehavior = nil
  }

  /// Override the default behavior and products of a paywall.
  ///
  /// Provide an instance of this to ``Superwall/getPaywall(forPlacement:params:paywallOverrides:delegate:)``.
  ///
  /// - parameters:
  ///   - products: A ``PaywallProducts`` object defining the products to override on the paywall.
  @available(swift, obsoleted: 1.0)
  @available(*, deprecated)
  public init(products: PaywallProducts?) {
    self.productsByName = Self.mapFromPaywallProducts(products)
    self.products = products
    self.ignoreSubscriptionStatus = false
    self.presentationStyle = .none
    self.featureGatingBehavior = nil
  }

  /// Override the default behavior and products of a paywall.
  ///
  /// Provide an instance of this to ``Superwall/getPaywall(forPlacement:params:paywallOverrides:delegate:)``.
  ///
  /// - parameters:
  ///   - products: A ``PaywallProducts`` object defining the products to override on the paywall.
  ///   - ignoreSubscriptionStatus: Set this to `true` to always show the paywall, regardless of whether the user has an active subscription or not.
  @available(swift, obsoleted: 1.0)
  @available(*, deprecated)
  public init(
    products: PaywallProducts?,
    ignoreSubscriptionStatus: Bool = false
  ) {
    self.productsByName = Self.mapFromPaywallProducts(products)
    self.products = products
    self.ignoreSubscriptionStatus = ignoreSubscriptionStatus
    self.presentationStyle = .none
    self.featureGatingBehavior = nil
  }

  private static func mapFromPaywallProducts(
    _ products: PaywallProducts?
  ) -> [String: StoreProduct] {
    var convertedProducts: [String: StoreProduct] = [:]
    if let primary = products?.primary {
      convertedProducts["primary"] = primary
    }
    if let secondary = products?.secondary {
      convertedProducts["secondary"] = secondary
    }
    if let tertiary = products?.tertiary {
      convertedProducts["tertiary"] = tertiary
    }
    return convertedProducts
  }

  private static func mapToPaywallProducts(
    _ products: [String: StoreProduct]
  ) -> PaywallProducts? {
    var primaryProduct: StoreProduct?
    var secondaryProduct: StoreProduct?
    var tertiaryProduct: StoreProduct?

    if let primary = products["primary"] {
      primaryProduct = primary
    }
    if let secondary = products["secondary"] {
      secondaryProduct = secondary
    }
    if let tertiary = products["tertiary"] {
      tertiaryProduct = tertiary
    }

    var paywallProducts: PaywallProducts?

    // Only initialise PaywallProducts if at least one product is not nil
    if primaryProduct != nil || secondaryProduct != nil || tertiaryProduct != nil {
      paywallProducts = PaywallProducts(
        primary: primaryProduct,
        secondary: secondaryProduct,
        tertiary: tertiaryProduct
      )
    }

    return paywallProducts
  }
}
