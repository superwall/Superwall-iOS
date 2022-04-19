//
//  StoreKitService.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 10/03/2022.
//

import StoreKit
import SwiftUI

final class StoreKitService: NSObject, ObservableObject {
  static let shared = StoreKitService()
  @Published var isSubscribed = false
  private(set) var purchasedIdentifiers = Set<String>()
  private var productIdsToName: [String: String] = [:]
  enum StoreError: Error {
    case failedVerification
  }

  override init() {
    super.init()
    SKPaymentQueue.default().add(self)
  }

  func purchase(_ product: SKProduct) async throws {
    let payment = SKPayment(product: product)
    SKPaymentQueue.default().add(payment)
  }

  func restorePurchases() -> Bool {
    let refresh = SKReceiptRefreshRequest()
    defer {
      refresh.cancel()
    }

    refresh.start()
    if refresh.receiptProperties?.isEmpty == false {
      isSubscribed = true
      return true
    }
    return false
  }

  func loadSubscriptionState() async {
    for await result in Transaction.currentEntitlements {
      guard case .verified(let transaction) = result else {
        continue
      }
      if transaction.revocationDate == nil {
        isSubscribed = true
        return
      }
    }
    isSubscribed = false
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
        isSubscribed = true
        SKPaymentQueue.default().finishTransaction(transaction)
      case .failed:
        SKPaymentQueue.default().finishTransaction(transaction)
      default:
        break
      }
    }
  }

  func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    isSubscribed = true
  }
}
