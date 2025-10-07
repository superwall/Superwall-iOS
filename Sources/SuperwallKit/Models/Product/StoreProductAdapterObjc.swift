//
//  StoreProductAdapterObjc.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 23/07/2025.
//

import Foundation

/// An objc-only type that specifies a store and a product.
@objc(SWKStoreProductAdapter)
@objcMembers
public final class StoreProductAdapterObjc: NSObject, Codable, Sendable {
  /// The store associated with the product.
  public let store: ProductStore

  /// The App Store product. This is non-nil if `store` is
  /// `appStore`.
  public let appStoreProduct: AppStoreProduct?

  /// The Stripe product. This is non-nil if `store` is
  /// `stripe`.
  public let stripeProduct: StripeProduct?

  init(
    store: ProductStore,
    appStoreProduct: AppStoreProduct?,
    stripeProduct: StripeProduct?
  ) {
    self.store = store
    self.appStoreProduct = appStoreProduct
    self.stripeProduct = stripeProduct
  }
}
