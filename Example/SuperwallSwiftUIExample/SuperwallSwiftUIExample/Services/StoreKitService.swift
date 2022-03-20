/// Copyright (c) 2022 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

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
