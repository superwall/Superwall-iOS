//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 01/11/2024.
//

import Foundation
import StoreKit

/// Represents the state of purchasing when observing purchases.
@objc public class PurchasingObserverState: NSObject {
  @available(iOS 15.0, *)
  enum SK2ObserverState {
    case purchaseBegin(StoreKit.Product)
    case purchaseResult(StoreKit.Product.PurchaseResult)
    case purchaseError(Error)
  }
  enum SK1ObserverState {
    case addToPaymentQueue(SK1Product)
    case updatedTransaction(SK1Transaction)
  }

  let sk1State: SK1ObserverState?

  // swiftlint:disable:next identifier_name
  var _sk2State: Any?
  @available(iOS 15.0, *)
  var sk2State: SK2ObserverState? {
    // swiftlint:disable:next force_cast force_unwrapping
    return self._sk2State as? SK2ObserverState
  }

  init(
    sk1State: SK1ObserverState? = nil,
    _sk2State: Any? = nil
  ) {
    self.sk1State = sk1State
    self._sk2State = _sk2State
  }

  // MARK: - StoreKit 2

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
  /// - Returns: A `PurchasingObserverState` object.
  @available(iOS 15.0, *)
  public static func purchaseWillBegin(for product: StoreKit.Product) -> PurchasingObserverState {
    return PurchasingObserverState(
      _sk2State: SK2ObserverState.purchaseBegin(product)
    )
  }

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
  @available(iOS 15.0, *)
  public static func purchaseResult(
    _ result: StoreKit.Product.PurchaseResult
  ) -> PurchasingObserverState {
    return PurchasingObserverState(
      _sk2State: SK2ObserverState.purchaseResult(result)
    )
  }

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
  /// - Returns: A `PurchasingObserverState` object.
  @available(iOS 15.0, *)
  public static func purchaseError(_ error: Error) -> PurchasingObserverState {
    return PurchasingObserverState(
      _sk2State: SK2ObserverState.purchaseError(error)
    )
  }

  // MARK: - StoreKit 1

  /// Indicates that the StoreKit 1 `SKPayment` will be added to the `SKPaymentQueue`.
  ///
  /// Call this **before** you call `SKPaymentQueue.default().add(payment)`:
  ///
  /// ```swift
  /// Superwall.shared.willAddToPaymentQueue(product)
  /// let payment = SKMutablePayment(product: product)
  /// SKPaymentQueue.default().add(payment)
  /// ```
  /// - Parameter product: The StoreKit 1 product that will be purchased.
  /// - Returns: A `PurchasingObserverState` object.
  public static func willAddToPaymentQueue(_ product: SKProduct) -> PurchasingObserverState {
    return PurchasingObserverState(
      sk1State: .addToPaymentQueue(product)
    )
  }

  /// Observes the updated transaction from the payment queue.
  ///
  /// Call this inside `paymentQueue(_:updatedTransactions:)`.
  ///
  /// ```swift
  /// Superwall.shared.willAddToPaymentQueue(product)
  /// let payment = SKMutablePayment(product: product)
  /// SKPaymentQueue.default().add(payment)
  /// ```
  /// - Parameter transaction: The StoreKit 1 transaction that received an update.
  /// - Returns: A `PurchasingObserverState` object.
  public static func updatedTransaction(
    _ transaction: SKPaymentTransaction
  ) -> PurchasingObserverState {
    return PurchasingObserverState(
      sk1State: .updatedTransaction(transaction)
    )
  }
}
