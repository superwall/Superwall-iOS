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
    Task(priority: .background) {
      for await verificationResult in Transaction.updates {
        guard case .verified(let transaction) = verificationResult else {
          return
        }
        await delegate?.transactionRecorder.record(transaction)
      }
    }
  }
}
