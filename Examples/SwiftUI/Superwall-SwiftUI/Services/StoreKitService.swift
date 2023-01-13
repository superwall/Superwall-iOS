//
//  StoreKitService.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

// Uncomment if you're implementing the SubscriptionController in SuperwallService.swift:
/*
import StoreKit
import SuperwallKit

final class StoreKitService: NSObject, ObservableObject {
  static let shared = StoreKitService()
  @Published var isSubscribed = false {
    didSet {
      UserDefaults.standard.set(isSubscribed, forKey: kIsSubscribed)
    }
  }
  private let kIsSubscribed = "isSubscribed"
  var completion: ((PurchaseResult) -> Void)?
  enum StoreError: Error {
    case failedVerification
  }

  override init() {
    super.init()
    isSubscribed = UserDefaults.standard.bool(forKey: kIsSubscribed)
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
      if let expirationDate = transaction.expirationDate,
        expirationDate < Date() {
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
        isSubscribed = true
        SKPaymentQueue.default().finishTransaction(transaction)
      default:
        break
      }
    }
  }
}
*/
