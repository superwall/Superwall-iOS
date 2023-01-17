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
  private var receiptRefreshCompletion: ((Bool) -> Void)?
  enum StoreError: Error {
    case failedVerification
  }

  override init() {
    super.init()
    isSubscribed = UserDefaults.standard.bool(forKey: kIsSubscribed)
    SKPaymentQueue.default().add(self)
  }

  func purchase(_ product: SKProduct) async -> PurchaseResult {
    return await withCheckedContinuation { continuation in
      let payment = SKPayment(product: product)
      self.completion = { result in
        continuation.resume(with: .success(result))
      }
      SKPaymentQueue.default().add(payment)
    }
  }

  func restorePurchases() async -> Bool {
    let isRefreshed = await withCheckedContinuation { continuation in
      let refresh = SKReceiptRefreshRequest()
      refresh.delegate = self
      refresh.start()
      receiptRefreshCompletion = { completed in
        continuation.resume(returning: completed)
      }
    }
    return isRefreshed
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

// MARK: - SKRequestDelegate
extension StoreKitService: SKRequestDelegate {
  func requestDidFinish(_ request: SKRequest) {
    guard request is SKReceiptRefreshRequest else {
      return
    }
    receiptRefreshCompletion?(true)
    request.cancel()
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    guard request is SKReceiptRefreshRequest else {
      return
    }
    receiptRefreshCompletion?(false)
    request.cancel()
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
        // TODO: Verify receipts.
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
