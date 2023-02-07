//
//  StoreKitService.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

// Uncomment if you're implementing the SubscriptionController in SuperwallService.swift:
import SuperwallKit

/*
import StoreKit
import SuperwallKit

final class StoreKitService: NSObject, ObservableObject {
  static let shared = StoreKitService()
  @Published var isSubscribed = false {
    didSet {
      if isSubscribed {
        Superwall.shared.setSubscriptionStatus(to: .active)
      } else {
        Superwall.shared.setSubscriptionStatus(to: .inactive)
      }
      UserDefaults.standard.set(isSubscribed, forKey: kIsSubscribed)
    }
  }
  private let kIsSubscribed = "isSubscribed"
  enum StoreError: Error {
    case failedVerification
  }
  private var purchaseCompletion: ((PurchaseResult) -> Void)?
  private var restoreCompletion: ((Bool) -> Void)?

  override init() {
    super.init()
    isSubscribed = UserDefaults.standard.bool(forKey: kIsSubscribed)
    SKPaymentQueue.default().add(self)
  }

  func purchase(_ product: SKProduct) async -> PurchaseResult {
    return await withCheckedContinuation { continuation in
      let payment = SKPayment(product: product)
      self.purchaseCompletion = { result in
        continuation.resume(with: .success(result))
      }
      SKPaymentQueue.default().add(payment)
    }
  }

  func restorePurchases() async -> Bool {
    let result = await withCheckedContinuation { continuation in
      // Using restoreCompletedTransactions instead of just refreshing
      // the receipt so that RC can pick up on the restored products,
      // if observing. It will also refresh the receipt on device.
      restoreCompletion = { completed in
        return continuation.resume(returning: completed)
      }
      SKPaymentQueue.default().restoreCompletedTransactions()
    }
    restoreCompletion = nil
    await loadSubscriptionState()
    return result
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
  func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    restoreCompletion?(true)
  }

  func paymentQueue(
    _ queue: SKPaymentQueue,
    restoreCompletedTransactionsFailedWithError error: Error
  ) {
    restoreCompletion?(false)
  }

  func paymentQueue(
    _ queue: SKPaymentQueue,
    updatedTransactions transactions: [SKPaymentTransaction]
  ) {
    for transaction in transactions {
      switch transaction.transactionState {
      case .purchased:
        // TODO: Verify receipts.
        isSubscribed = true
        SKPaymentQueue.default().finishTransaction(transaction)
        purchaseCompletion?(.purchased)
        purchaseCompletion = nil
      case .failed:
        if let error = transaction.error {
          if let error = error as? SKError {
            switch error.code {
            case .overlayTimeout,
              .paymentCancelled,
              .overlayCancelled:
              purchaseCompletion?(.cancelled)
              purchaseCompletion = nil
              SKPaymentQueue.default().finishTransaction(transaction)
              return
            default:
              break
            }
          }
          purchaseCompletion?(.failed(error))
          purchaseCompletion = nil
        }
        SKPaymentQueue.default().finishTransaction(transaction)
      case .deferred:
        purchaseCompletion?(.pending)
        purchaseCompletion = nil
      case .restored:
        SKPaymentQueue.default().finishTransaction(transaction)
      default:
        break
      }
    }
  }
}
*/
