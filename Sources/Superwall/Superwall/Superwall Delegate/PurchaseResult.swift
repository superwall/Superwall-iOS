//
//  File.swift
//  
//
//  Created by Yusuf Tör on 18/10/2022.
//

import Foundation

/// An enum that defines the possible outcomes of attempting to purchase a product.
public enum PurchaseResult {
  /// The purchase was cancelled.
  ///
  /// In StoreKit 1, you can detect this by switching over the error code from the `.failed`
  /// transaction state. The following cases should all be reported as a `.cancelled` state to
  /// Superwall:
  /// - `.overlayCancelled`,
  /// - `.paymentCancelled`,
  /// - `.overlayTimeout`
  ///
  /// In StoreKit 2, this is the `.userCancelled` error state.
  ///
  /// With RevenueCat, this is when the `userCancelled` boolean returned from the purchase
  /// method is `true`.
  case cancelled

  /// The product was purchased.
  case purchased

  /// The purchase is pending and requires action from the developer.
  ///
  /// In StoreKit 1, this is the same as the `.deferred` transaction state.
  ///
  /// In StoreKit 2, this is the same as the `.pending` purchase result.
  ///
  /// With RevenueCat, this is the same as the `.paymentPendingError`.
  case pending

  /// The purchase failed for a reason other than the user cancelling or the payment pending.
  ///
  /// Send the `Error` back to Superwall to alert the user.
  case failed(Error)
}

// MARK: - Objective -C

/*
 Note: In the following enum we don't mention StoreKit 2. This is because StoreKit 2
 isn't supported by Objective-c.
 */


/// An Objective-C-only enum that defines the possible outcomes of attempting to purchase a product.
@objc public enum PurchaseResultObjc: Int {
  /// The purchase was cancelled.
  ///
  /// In StoreKit 1, you can detect this by switching over the error code from the `.failed`
  /// transaction state. The following cases should all be reported as a `.cancelled` state to
  /// Superwall:
  /// - `.overlayCancelled`,
  /// - `.paymentCancelled`,
  /// - `.overlayTimeout`
  ///
  /// With RevenueCat, this is when the `userCancelled` boolean returned from the purchase
  /// method is `true`.
  case cancelled

  /// The product was purchased.
  case purchased

  /// The purchase is pending and requires action from the developer.
  ///
  /// In StoreKit 1, this is the same as the `.deferred` transaction state.
  ///
  /// With RevenueCat, this is the same as the `.paymentPendingError`.
  case pending

  /// The purchase failed for a reason other than the user cancelling or the payment pending.
  ///
  /// Send the `Error` back in the ``SuperwallDelegateObjc/purchase(product:completion:)``
  /// completion block to Superwall to alert the user.
  case failed
}
