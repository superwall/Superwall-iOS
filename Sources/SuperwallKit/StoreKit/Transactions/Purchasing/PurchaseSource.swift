//
//  PurchaseSource.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 01/10/2024.
//

/// The source of the purchase initiation.
enum PurchaseSource {
  #if canImport(WebKit)
  /// The purchase was initiated internally by the SDK, for the slot with this `Product.cacheKey`.
  case `internal`(String, PurchasingPaywall, Bool)
  #endif

  /// The purchase was initiated externally by the user calling ``Superwall/purchase(_:)-7gwwe``.
  case purchaseFunc(StoreProduct)

  case observeFunc(StoreProduct)

  func toRestoreSource() -> RestoreSource {
    switch self {
    #if canImport(WebKit)
    case .internal(_, let paywallViewController, _): return .internal(paywallViewController)
    #endif
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
  #if canImport(WebKit)
  /// Initiated internally by the SDK.
  case `internal`(PurchasingPaywall)
  #endif

  /// Initiated externally by the user.
  case external

  static func == (lhs: RestoreSource, rhs: RestoreSource) -> Bool {
    switch (lhs, rhs) {
    case (.external, .external):
      return true
    #if canImport(WebKit)
    case let (.internal(lhsPaywall), .internal(rhsPaywall)):
      return lhsPaywall === rhsPaywall
    default:
      return false
    #endif
    }
  }
}

typealias GenericSource = RestoreSource
