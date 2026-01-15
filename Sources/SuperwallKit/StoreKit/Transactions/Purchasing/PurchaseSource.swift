//
//  PurchaseSource.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 01/10/2024.
//

/// The source of the purchase initiation.
enum PurchaseSource {
  /// The purchase was initiated internally by the SDK.
  case `internal`(String, PaywallViewController, Bool)

  /// The purchase was initiated externally by the user calling ``Superwall/purchase(_:)-7gwwe``.
  case purchaseFunc(StoreProduct)

  case observeFunc(StoreProduct)

  func toRestoreSource() -> RestoreSource {
    switch self {
    case .internal(_, let paywallViewController, _): return .internal(paywallViewController)
    case .purchaseFunc: return .external
    case .observeFunc: return .external
    }
  }

  func toGenericSource() -> GenericSource {
    return self.toRestoreSource()
  }
}

/// The source of the restore initiation.
enum RestoreSource: Equatable {
  /// Initiated internally by the SDK.
  case `internal`(PaywallViewController)

  /// Initiated externally by the user.
  case external
}

typealias GenericSource = RestoreSource
