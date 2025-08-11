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

  /// Sets a custom presentation style for the paywall.
  public let presentationStyle: PaywallPresentationStyle

  // Objective-C compatibility properties (stored privately)
  private let _presentationStyleObjc: PaywallPresentationStyleObjc
  private let _drawerHeight: NSNumber?
  private let _drawerCornerRadius: NSNumber?

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
  ///   - presentationStyleOverride: A ``PaywallPresentationStyle`` enum that specifies the presentation style for the paywall.
  public init(
    productsByName: [String: StoreProduct] = [:],
    presentationStyleOverride: PaywallPresentationStyle = .none
  ) {
    self.productsByName = productsByName
    self.presentationStyle = presentationStyleOverride
    self._presentationStyleObjc = presentationStyleOverride.toObjcStyle()
    self._drawerHeight = presentationStyleOverride.drawerHeight
    self._drawerCornerRadius = presentationStyleOverride.drawerCornerRadius
    self.featureGatingBehavior = nil
  }

  /// Override the default behavior and products of a paywall (Objective-C compatible).
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
  ///   - presentationStyleOverride: A ``PaywallPresentationStyleObjc`` enum that specifies the presentation style for the paywall.
  @available(swift, obsoleted: 1.0)
  public init(
    productsByName: [String: StoreProduct] = [:],
    presentationStyleOverride: PaywallPresentationStyleObjc = .none
  ) {
    self.productsByName = productsByName
    self._presentationStyleObjc = presentationStyleOverride
    self._drawerHeight = nil
    self._drawerCornerRadius = nil
    self.presentationStyle = presentationStyleOverride.toSwift(
      height: nil,
      cornerRadius: nil
    )
    self.featureGatingBehavior = nil
  }

  /// Override the default behavior and products of a paywall (Objective-C compatible).
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
  ///   - presentationStyleOverride: A ``PaywallPresentationStyleObjc`` enum that specifies the presentation style for the paywall.
  ///   - drawerHeight: The height for drawer presentation (only used when presentationStyleOverride is .drawer).
  ///   - drawerCornerRadius: The corner radius for drawer presentation (only used when presentationStyleOverride is .drawer).
  @available(swift, obsoleted: 1.0)
  public init(
    productsByName: [String: StoreProduct],
    presentationStyleOverride: PaywallPresentationStyleObjc,
    drawerHeight: NSNumber? = nil,
    drawerCornerRadius: NSNumber? = nil
  ) {
    self.productsByName = productsByName
    self._presentationStyleObjc = presentationStyleOverride
    self._drawerHeight = drawerHeight
    self._drawerCornerRadius = drawerCornerRadius
    self.presentationStyle = presentationStyleOverride.toSwift(
      height: drawerHeight,
      cornerRadius: drawerCornerRadius
    )
    self.featureGatingBehavior = nil
  }

  /// Internal init used for overriding the feature gating behavior for implicitly triggered paywalls.
  init(featureGatingBehavior: FeatureGatingBehavior) {
    self.productsByName = [:]
    self.presentationStyle = .none
    self._presentationStyleObjc = .none
    self._drawerHeight = nil
    self._drawerCornerRadius = nil
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
    self.presentationStyle = .none
    self._presentationStyleObjc = .none
    self._drawerHeight = nil
    self._drawerCornerRadius = nil
    self.featureGatingBehavior = nil
  }
}

// MARK: - Objective-C Compatibility
extension PaywallOverrides {
  /// Sets a custom presentation style for the paywall (Objective-C compatible).
  @available(swift, obsoleted: 1.0)
  @objc public var presentationStyleObjc: PaywallPresentationStyleObjc {
    return _presentationStyleObjc
  }

  /// The height for drawer presentation style when using Objective-C API.
  @available(swift, obsoleted: 1.0)
  @objc public var drawerHeight: NSNumber? {
    return _drawerHeight
  }

  /// The corner radius for drawer presentation style when using Objective-C API.
  @available(swift, obsoleted: 1.0)
  @objc public var drawerCornerRadius: NSNumber? {
    return _drawerCornerRadius
  }
}
