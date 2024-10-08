//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 20/09/2024.
//

import Foundation
import StoreKit

@available(iOS 15.0, *)
actor SK2TransactionListener {
  private(set) var taskHandle: Task<Void, Never>?
  private let factory: HasExternalPurchaseControllerFactory
  private unowned let receiptManager: ReceiptManager

  deinit {
    self.taskHandle?.cancel()
    self.taskHandle = nil
  }

  init(
    receiptManager: ReceiptManager,
    factory: HasExternalPurchaseControllerFactory
  ) {
    self.receiptManager = receiptManager
    self.factory = factory
  }

  func listenForTransactions() {
    self.taskHandle?.cancel()
    self.taskHandle = Task(priority: .utility) { [weak self] in
      for await result in Transaction.updates {
        guard let self = self else { break }
        switch result {
        case let .verified(transaction),
          let .unverified(transaction, _):

          if await !factory.makeHasExternalPurchaseController() {
            await transaction.finish()
          }

          // TODO: We should be more smart here. This will run through Transaction.all every time there's an update. Do we really need to do that? Consider products previously expiring in solution to, maybe we do need to.
          await receiptManager.loadPurchasedProducts()
        }
      }
    }
  }
}
