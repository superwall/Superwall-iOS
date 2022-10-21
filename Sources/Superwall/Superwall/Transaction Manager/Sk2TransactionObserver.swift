//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/10/2022.
//

import StoreKit

@available(iOS 15, *)
final class Sk2TransactionObserver {
  var updates: Task<Void, Never>?

  init() {
    updates = newTransactionObserverTask()
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
    if let revocationDate = transaction.revocationDate {
      // Remove access to the product identified by transaction.productID.
      // Transaction.revocationReason provides details about
      // the revoked transaction.
    } else if let expirationDate = transaction.expirationDate,
      expirationDate < Date() {
      // Do nothing, this subscription is expired.
      return
    } else if transaction.isUpgraded {
      // Do nothing, there is an active transaction
      // for a higher level of service.
      return
    } else {
      print("TRANSACTION HANDLED", transaction)
      // Provide access to the product identified by
      // transaction.productID.
      await SessionEventsManager.shared
        .transactionRecorder
        .record(transaction)

      print("got here")
    }
  }
}
