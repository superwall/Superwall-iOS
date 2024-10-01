//
//  PurchaseSource.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 01/10/2024.
//

/// The source of the purchase initiation.
enum PurchaseSource {
  /// The purchase was initiated internally by the SDK.
  case `internal`(String, PaywallViewController)

  /// The purchae was initiated externally by the user calling ``Superwall/purchase(_:)-7gwwe``.
  case external(StoreProduct)
}
