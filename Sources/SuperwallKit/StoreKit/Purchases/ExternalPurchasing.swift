//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 27/09/2024.
//

import Foundation

extension Superwall {
  /// Purchases a ``StoreProduct``.
  public func purchase(_ product: StoreProduct) async -> PurchaseResult {
    return await dependencyContainer.transactionManager.purchase(.external(product))
  }

  /// Objective-C-only method. Purchases a ``StoreProduct``.
  @available(swift, obsoleted: 1.0)
  public func purchase(_ product: StoreProduct) async -> PurchaseResultObjc {
    let result = await dependencyContainer.transactionManager.purchase(.external(product))
    return result.toObjc()
  }
}
