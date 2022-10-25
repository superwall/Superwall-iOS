//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/10/2022.
//

import StoreKit

@available(iOS 15, *)
final class Sk2TransactionObserver {
  private var updates: Task<Void, Never>?
  weak var delegate: TransactionObserverDelegate?

  init(delegate: TransactionObserverDelegate) {
    updates = newTransactionObserverTask()
    self.delegate = delegate
  }

  deinit {
    // Cancel the update handling task when you deinitialize the class.
    updates?.cancel()
  }

  private func newTransactionObserverTask() -> Task<Void, Never> {
    Task(priority: .utility) { [weak self] in
      for await verificationResult in Transaction.updates {
        await self?.handle(updatedTransaction: verificationResult)
      }
    }
  }

  private func handle(updatedTransaction verificationResult: VerificationResult<Transaction>) async {
    guard case .verified(let transaction) = verificationResult else {
      return
    }

    await SessionEventsManager.shared
      .transactionRecorder
      .record(transaction)

    guard let product = StoreKitManager.shared.productsById[transaction.productID] else {
      return
    }

    if transaction.revocationDate != nil {
      // Transaction revoked.
      return
    } else if let expirationDate = transaction.expirationDate,
      expirationDate < Date() {
      // Subscription expired.
      return
    } else if transaction.isUpgraded {
      // There is an active transaction for a higher
      // level of service.
      return
    } else {
      // Provide access to the product identified by
      // transaction.productID.

      await self.delegate?.trackTransactionDidSucceed(
        withId: "\(transaction.id)",
        product: product
      )
    }
  }
}
