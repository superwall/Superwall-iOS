//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 05/11/2024.
//

import StoreKit

@available(iOS 15.0, *)
extension StoreKit.Product.PurchaseResult {
  /// Converts a StoreKit 2 `PurchaseResult` to a Superwall `PurchaseResult`.
  func toInternalPurchaseResult(_ coordinator: PurchasingCoordinator) async -> PurchaseResult {
    switch self {
    case .success(let verificationResult):
      switch verificationResult {
      case .unverified(_, let error):
        return .failed(error)
      case .verified(let transaction):
        return .purchased
      }
    case .userCancelled:
      return .cancelled
    case .pending:
      return .pending
    @unknown default:
      return .failed(PurchaseError.unknown)
    }
  }
}
