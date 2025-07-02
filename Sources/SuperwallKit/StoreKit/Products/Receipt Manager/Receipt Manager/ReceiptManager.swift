//
//  File.swift
//
//
//  Created by Yusuf Tör on 24/03/2022.
//

import Foundation
import StoreKit

protocol ReceiptDelegate: AnyObject {
  func syncSubscriptionStatus(purchases: Set<Purchase>) async
}

struct Purchase: Hashable {
  let id: String
  let isActive: Bool
  let purchaseDate: Date
}

actor ReceiptManager {
  private var receiptRefreshCompletion: ((Bool) -> Void)?
  private unowned let productsManager: ProductsManager
  private weak var receiptDelegate: ReceiptDelegate?
  private let storeKitVersion: SuperwallOptions.StoreKitVersion
  private let manager: ReceiptManagerType
  private let delegateWrapper: ReceiptRefreshDelegateWrapper
  private unowned let factory: ConfigStateFactory
  static var appTransactionId: String?

  init(
    storeKitVersion: SuperwallOptions.StoreKitVersion,
    productsManager: ProductsManager,
    receiptManager: ReceiptManagerType? = nil, // For testing
    receiptDelegate: ReceiptDelegate?,
    factory: ConfigStateFactory
  ) {
    self.storeKitVersion = storeKitVersion
    self.productsManager = productsManager
    self.factory = factory

    if let receiptManager = receiptManager {
      self.manager = receiptManager
    } else if #available(iOS 15.0, *),
      storeKitVersion == .storeKit2 {
      self.manager = Self.versionedManager(storeKitVersion: storeKitVersion)
    } else {
      self.manager = SK1ReceiptManager()
    }
    self.receiptDelegate = receiptDelegate
    self.delegateWrapper = ReceiptRefreshDelegateWrapper()
    self.delegateWrapper.receiptManager = self

    Task {
      await setAppTransactionId()
    }
  }

  static func versionedManager(
    storeKitVersion: SuperwallOptions.StoreKitVersion
  ) -> ReceiptManagerType {
    if #available(iOS 15.0, *),
      storeKitVersion == .storeKit2 {
      return SK2ReceiptManager()
    } else {
      return SK1ReceiptManager()
    }
  }

  func getTransactionReceipts() async -> [TransactionReceipt] {
    await manager.transactionReceipts
  }

  private func setAppTransactionId() async {
    #if compiler(>=6.1)
    if #available(iOS 16.0, *) {
      if let result = try? await AppTransaction.shared {
        switch result {
        case .verified(let transaction),
          .unverified(let transaction, _):
          Self.appTransactionId = transaction.appTransactionID
        }
      }
    }
    #endif
  }

  func getExperimentalDeviceProperties() async -> [String: Any] {
    async let periodType = manager.latestSubscriptionPeriodType?.rawValue
    async let state = manager.latestSubscriptionState?.rawValue
    async let willAutoRenew = manager.latestSubscriptionWillAutoRenew

    let (unwrappedPeriodType, unwrappedState, unwrappedWillAutoRenew) = await (periodType, state, willAutoRenew)

    var values: [String: Any] = [:]

    if let periodType = unwrappedPeriodType {
      values["latestSubscriptionPeriodType"] = periodType
    }

    if let state = unwrappedState {
      values["latestSubscriptionState"] = state
    }

    if let willAutoRenew = unwrappedWillAutoRenew {
      values["latestSubscriptionWillAutoRenew"] = willAutoRenew
    }
    return values
  }

  /// Loads purchased products from the receipt, storing the purchased subscription group identifiers, purchases and active purchases.
  func loadPurchasedProducts(config: Config?) async {
    let resolvedConfig: Config?

    if let config = config {
      resolvedConfig = config
    } else {
      let configState = factory.makeConfigState()
      do {
        resolvedConfig = try await configState
          .compactMap { $0.getConfig() }
          .throwableAsync()
      } catch {
        return
      }
    }

    guard let config = resolvedConfig else {
      // Neither input config nor config from state is available
      return
    }

    let serverEntitlementsByProductId = ConfigLogic.extractEntitlements(from: config)
    let snapshot = await manager.loadPurchases(serverEntitlementsByProductId: serverEntitlementsByProductId)

    await MainActor.run {
      Superwall.shared.customerInfo = CustomerInfo(
        activeSubscriptions: snapshot.activeSubscriptions,
        nonSubscriptions: snapshot.nonSubscriptions,
        userId: Superwall.shared.userId,
        entitlements: snapshot.entitlementsByProductId.values
          .flatMap { $0 }
          .sorted { $0.id < $1.id }
      )
    }

    Superwall.shared.entitlements.setEntitlementsFromConfig(snapshot.entitlementsByProductId)

    await receiptDelegate?.syncSubscriptionStatus(purchases: snapshot.purchases)

    let purchasedProductIds = Set(snapshot.purchases.map { $0.id })

    guard let storeProducts = try? await productsManager.products(
      identifiers: purchasedProductIds,
      forPaywall: nil,
      placement: nil
    ) else {
      return
    }

    await manager.loadIntroOfferEligibility(forProducts: storeProducts)
  }

  /// Determines whether a free trial is available based on the product the user is purchasing.
  ///
  /// A free trial is available if the user hasn't already purchased within the subscription group of the
  /// supplied product. If it isn't a subscription-based product or there are other issues retrieving the products,
  /// the outcome will default to whether or not the user has already purchased that product.
  func isFreeTrialAvailable(for storeProduct: StoreProduct) async -> Bool {
    await manager.isEligibleForIntroOffer(storeProduct)
  }

  /// Determines whether the user is subscribed to the given product id.
  func isSubscribed(to productId: String) async -> Bool {
    return await manager.purchases
      .filter { $0.id == productId }
      .sorted { $0.purchaseDate > $1.purchaseDate }
      .first?
      .isActive == true
  }

  func getActiveProductIds() async -> Set<String> {
    return await Set(
      manager.purchases
      .filter(\.isActive)
      .map(\.id)
    )
  }

  /// This refreshes the device receipt.
  ///
  /// - Warning: This will prompt the user to log in, so only do this on
  /// when restoring or after purchasing.
  func refreshSK1Receipt() async {
    guard storeKitVersion == .storeKit1 else {
      return
    }
    Logger.debug(
      logLevel: .debug,
      scope: .receipts,
      message: "Refreshing receipts"
    )

    // Don't need the result at the moment.
    _ = await withCheckedContinuation { continuation in
      let refresh = SKReceiptRefreshRequest()
      refresh.delegate = delegateWrapper
      refresh.start()
      receiptRefreshCompletion = { completed in
        continuation.resume(returning: completed)
      }
    }
  }

  func receiptRefreshDidFinish(request: SKRequest) {
    guard request is SKReceiptRefreshRequest else {
      return
    }
    Logger.debug(
      logLevel: .debug,
      scope: .transactions,
      message: "Receipt refresh request finished.",
      info: ["request": request]
    )

    receiptRefreshCompletion?(true)

    request.cancel()
  }

  func receiptRefreshDidFail(
    request: SKRequest,
    error: Error
  ) {
    guard request is SKReceiptRefreshRequest else {
      return
    }
    Logger.debug(
      logLevel: .error,
      scope: .transactions,
      message: "Receipt refresh request failed.",
      info: ["request": request],
      error: error
    )
    receiptRefreshCompletion?(false)

    request.cancel()
  }
}

final class ReceiptRefreshDelegateWrapper: NSObject, SKRequestDelegate {
  weak var receiptManager: ReceiptManager?

  func requestDidFinish(_ request: SKRequest) {
    Task {
      await receiptManager?.receiptRefreshDidFinish(request: request)
    }
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    Task {
      await receiptManager?.receiptRefreshDidFail(
        request: request,
        error: error
      )
    }
  }
}
