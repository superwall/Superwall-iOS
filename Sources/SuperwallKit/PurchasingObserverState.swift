//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 01/11/2024.
//

import Foundation
import StoreKit

/// Represents the state of purchasing when observing purchases.
@available(iOS 15.0, *)
public enum PurchasingObserverState {
  /// Indicates that the StoreKit 2 purchase will begin.
  ///
  /// Call this **before** you call `product.purchase()`:
  ///
  /// ```swift
  /// do {
  ///   Superwall.shared.observe(.purchaseWillBegin(for: product))
  ///   let result = try await product.purchase()
  ///   Superwall.shared.observe(.purchaseResult(result))
  /// } catch let error {
  ///   Superwall.shared.observe(.purchaseError(error))
  /// }
  /// ```
  /// - Parameter product: The StoreKit 2 product that will be purchased.
  case purchaseWillBegin(for: StoreKit.Product)

  /// Observes the purchase result after purchasing a StoreKit 2 product.
  ///
  /// Call this **after** you call `product.purchase()`:
  ///
  /// ```swift
  /// do {
  ///   Superwall.shared.observe(.purchaseWillBegin(for: product))
  ///   let result = try await product.purchase()
  ///   Superwall.shared.observe(.purchaseResult(result))
  /// } catch let error {
  ///   Superwall.shared.observe(.purchaseError(error))
  /// }
  /// ```
  /// - Parameter result: The StoreKit 2 `PurchaseResult`.
  /// - Returns: A `PurchasingObserverState` object.
  case purchaseResult(StoreKit.Product.PurchaseResult)

  /// Indicates there was an error when purchasing a StoreKit 2 product.
  ///
  /// Call this in the `catch` block of your purchase flow:
  ///
  /// ```swift
  /// do {
  ///   Superwall.shared.observe(.purchaseWillBegin(for: product))
  ///   let result = try await product.purchase()
  ///   Superwall.shared.observe(.purchaseResult(result))
  /// } catch let error {
  ///   Superwall.shared.observe(.purchaseError(error))
  /// }
  /// ```
  /// - Parameter error: The StoreKit 2 error.
  case purchaseError(Error)
}
