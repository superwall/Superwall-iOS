//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 19/09/2024.
//

import Foundation

protocol Purchasing {
  func purchase(product: StoreProduct) async -> PurchaseResult
  func restorePurchases() async -> RestorationResult
}

final class PurchaseManager: Purchasing {
  let coordinator: PurchasingCoordinator
  private let purchaser: Purchasing

  // swiftlint:disable:next identifier_name
  var _sk2TransactionListener: Any?
  @available(iOS 15.0, *)
  var sk2TransactionListener: SK2TransactionListener {
    // swiftlint:disable:next force_cast force_unwrapping
    return self._sk2TransactionListener! as! SK2TransactionListener
  }
  let isUsingSK2: Bool

  init(
    storeKitVersion: SuperwallOptions.StoreKitVersion,
    storeKitManager: StoreKitManager,
    receiptManager: ReceiptManager,
    identityManager: IdentityManager,
    storage: Storage,
    factory: HasExternalPurchaseControllerFactory
      & StoreTransactionFactory
      & OptionsFactory
      & TransactionManagerFactory
  ) {
    coordinator = PurchasingCoordinator(factory: factory)
    if #available(iOS 15.0, *),
      storeKitVersion == .storeKit2 {
      purchaser = ProductPurchaserSK2(
        identityManager: identityManager,
        receiptManager: receiptManager,
        factory: factory
      )
      self._sk2TransactionListener = SK2TransactionListener(
        receiptManager: receiptManager,
        factory: factory
      )
      isUsingSK2 = true
      Task {
        await sk2TransactionListener.listenForTransactions()
      }
    } else {
      purchaser = ProductPurchaserSK1(
        storeKitManager: storeKitManager,
        receiptManager: receiptManager,
        identityManager: identityManager,
        coordinator: coordinator,
        storage: storage,
        factory: factory
      )
      isUsingSK2 = false
    }
  }

  func purchase(product: StoreProduct) async -> PurchaseResult {
    return await purchaser.purchase(product: product)
  }

  func restorePurchases() async -> RestorationResult {
    return await purchaser.restorePurchases()
  }
}
