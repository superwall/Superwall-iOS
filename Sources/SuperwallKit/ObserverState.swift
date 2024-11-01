//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 01/11/2024.
//

import Foundation
import StoreKit

@objc public class ObserverState: NSObject {
  @available(iOS 15.0, *)
  enum SK2ObserverState {
    case purchaseBegin(StoreKit.Product)
    case purchaseResult(StoreKit.Product, StoreKit.Product.PurchaseResult)
    case purchaseError(StoreKit.Product, Error)
  }
  enum SK1ObserverState {
    case addToPaymentQueue(SK1Product)
    case finishTransaction(SK1Transaction)
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

  @available(iOS 15.0, *)
  public static func purchaseBegin(product: StoreKit.Product) -> ObserverState {
    return ObserverState(
      _sk2State: SK2ObserverState.purchaseBegin(product)
    )
  }

  @available(iOS 15.0, *)
  public static func purchaseResult(
    product: StoreKit.Product,
    result: StoreKit.Product.PurchaseResult
  ) -> ObserverState {
    return ObserverState(
      _sk2State: SK2ObserverState.purchaseResult(product, result)
    )
  }

  @available(iOS 15.0, *)
  public static func purchaseError(
    product: StoreKit.Product,
    error: Error
  ) -> ObserverState {
    return ObserverState(
      _sk2State: SK2ObserverState.purchaseError(product, error)
    )
  }

  public static func addToPaymentQueue(
    product: SK1Product
  ) -> ObserverState {
    return ObserverState(
      sk1State: .addToPaymentQueue(product)
    )
  }

  public static func finishTransaction(
    transaction: SK1Transaction
  ) -> ObserverState {
    return ObserverState(
      sk1State: .finishTransaction(transaction)
    )
  }
}
