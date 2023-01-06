//
//  File.swift
//  
//
//  Created by Yusuf Tör on 24/03/2022.
//

import Foundation
import StoreKit

final class ReceiptManager: NSObject {
  var purchasedSubscriptionGroupIds: Set<String>?
  var purchases: Set<InAppPurchase> = []
  var activePurchases: Set<InAppPurchase> = [] {
    didSet {
      Superwall.shared.hasActiveSubscription = !activePurchases.isEmpty
    }
  }

  private var receiptRefreshCompletion: ((Bool) -> Void)?
  private weak var delegate: ProductsFetcher?
  private let receiptData: () -> Data?

  init(
    delegate: ProductsFetcher,
    receiptData: @escaping () -> Data? = ReceiptLogic.getReceiptData
  ) {
    self.delegate = delegate
    self.receiptData = receiptData
  }

  /// Loads purchased products from the receipt, storing the purchased subscription group identifiers,
  /// purchases and active purchases.
  @discardableResult
  func loadPurchasedProducts() async -> Set<StoreProduct>? {
    guard let payload = ReceiptLogic.getPayload(using: receiptData) else {
      return nil
    }
    guard let delegate = delegate else {
      return nil
    }

    let purchases = payload.purchases
    self.purchases = purchases
    activePurchases = purchases.filter { $0.isActive }

    let purchasedProductIds = Set(purchases.map { $0.productIdentifier })

    do {
      let products = try await delegate.products(identifiers: purchasedProductIds)

      var purchasedSubscriptionGroupIds: Set<String> = []
      for product in products {
        if let subscriptionGroupIdentifier = product.subscriptionGroupIdentifier {
          purchasedSubscriptionGroupIds.insert(subscriptionGroupIdentifier)
        }
      }
      self.purchasedSubscriptionGroupIds = purchasedSubscriptionGroupIds
      return products
    } catch {
      return nil
    }
  }

  /// Determines whether a free trial is available based on the product the user is purchasing.
  ///
  /// A free trial is available if the user hasn't already purchased within the subscription group of the
  /// supplied product. If it isn't a subscription-based product or there are other issues retrieving the products,
  /// the outcome will default to whether or not the user has already purchased that product.
  func isFreeTrialAvailable(for product: StoreProduct) -> Bool {
    guard product.hasFreeTrial else {
      return false
    }
    guard
      let purchasedSubsGroupIds = purchasedSubscriptionGroupIds,
      let subsGroupId = product.subscriptionGroupIdentifier
    else {
      return !hasPurchasedProduct(withId: product.productIdentifier)
    }

    return !purchasedSubsGroupIds.contains(subsGroupId)
  }

  /// Refreshes the receipt.
  func refreshReceipt() async -> Bool {
    Logger.debug(
      logLevel: .debug,
      scope: .receipts,
      message: "Refreshing receipts"
    )
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

  func addSubscriptionGroupId(_ id: String?) {
    guard let id = id else {
      return
    }
    if var purchasedSubscriptionGroupIds = purchasedSubscriptionGroupIds {
      purchasedSubscriptionGroupIds.insert(id)
    }
    purchasedSubscriptionGroupIds = [id]
  }

  /// Determines whether the purchases already contain the given product ID.
  func hasPurchasedProduct(withId productId: String) -> Bool {
    return purchases.first { $0.productIdentifier == productId } != nil
  }
}

extension ReceiptManager: SKRequestDelegate {
  func requestDidFinish(_ request: SKRequest) {
    guard request is SKReceiptRefreshRequest else {
      return
    }
    Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Receipt refresh request finished.",
      info: ["request": request]
    )
    receiptRefreshCompletion?(true)
    request.cancel()
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    guard request is SKReceiptRefreshRequest else {
      return
    }
    Logger.debug(
      logLevel: .error,
      scope: .paywallTransactions,
      message: "Receipt refresh request failed.",
      info: ["request": request],
      error: error
    )
    receiptRefreshCompletion?(false)
    request.cancel()
  }
}
