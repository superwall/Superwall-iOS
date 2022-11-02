//
//  StoreKitService.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 10/03/2022.
//

import StoreKit
import Combine
import SuperwallKit

final class StoreKitService: NSObject, ObservableObject {
  static let shared = StoreKitService()
  var isSubscribed = CurrentValueSubject<Bool, Never>(false)
  var completion: ((PurchaseResult) -> Void)?
  enum StoreError: Error {
    case failedVerification
  }

  override init() {
    super.init()
    SKPaymentQueue.default().add(self)
  }

  func purchase(
    _ product: SKProduct,
    completion: @escaping (PurchaseResult) -> Void
  ) {
    let payment = SKPayment(product: product)
    self.completion = completion
    SKPaymentQueue.default().add(payment)
  }

  func restorePurchases() -> Bool {
    let refresh = SKReceiptRefreshRequest()
    defer {
      refresh.cancel()
    }

    refresh.start()
    if refresh.receiptProperties?.isEmpty == false {
      isSubscribed.send(true)
      return true
    }
    return false
  }

  func loadSubscriptionState() async {
    for await result in Transaction.currentEntitlements {
      guard case .verified(let transaction) = result else {
        continue
      }
      if let expirationDate = transaction.expirationDate,
        expirationDate < Date() {
        continue
      }
      if transaction.revocationDate == nil {
        isSubscribed.send(true)
        return
      }
    }
    isSubscribed.send(false)
  }
}

// MARK: - SKPaymentTransactionObserver
extension StoreKitService: SKPaymentTransactionObserver {
  func paymentQueue(
    _ queue: SKPaymentQueue,
    updatedTransactions transactions: [SKPaymentTransaction]
  ) {
    for transaction in transactions {
      switch transaction.transactionState {
      case .purchased:
        isSubscribed.send(true)
        SKPaymentQueue.default().finishTransaction(transaction)
        completion?(.purchased)
        completion = nil
      case .failed:
        if let error = transaction.error {
          if let error = error as? SKError {
            switch error.code {
            case .overlayTimeout,
              .paymentCancelled,
              .overlayCancelled:
              completion?(.cancelled)
              completion = nil
              SKPaymentQueue.default().finishTransaction(transaction)
              return
            default:
              break
            }
          }
          completion?(.failed(error))
          completion = nil
        }
        SKPaymentQueue.default().finishTransaction(transaction)
      case .deferred:
        completion?(.pending)
        completion = nil
      case .restored:
        SKPaymentQueue.default().finishTransaction(transaction)
      default:
        break
      }
    }
  }

  func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    isSubscribed.send(true)
  }
}
