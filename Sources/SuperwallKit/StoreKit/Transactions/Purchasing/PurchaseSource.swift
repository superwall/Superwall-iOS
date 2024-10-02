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

  /// The purchase was initiated externally by the user calling ``Superwall/purchase(_:)-7gwwe``.
  case external(StoreProduct)

  func toRestoreSource() -> RestoreSource {
    switch self {
    case .internal(_, let paywallViewController): return .internal(paywallViewController)
    case .external: return .external
    }
  }

  func toGenericSource() -> GenericSource {
    return self.toRestoreSource()
  }
}

/// The source of the purchase initiation.
enum RestoreSource {
  /// Initiated internally by the SDK.
  case `internal`(PaywallViewController)

  /// Initiated externally by the user.
  case external
}

typealias GenericSource = RestoreSource
