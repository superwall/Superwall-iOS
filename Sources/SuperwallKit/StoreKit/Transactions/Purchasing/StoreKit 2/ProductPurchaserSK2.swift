//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 19/09/2024.
//

import Foundation
import StoreKit

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class ProductPurchaserSK2: Purchasing {
  private unowned let identityManager: IdentityManager
  private unowned let receiptManager: ReceiptManager
  private let coordinator: PurchasingCoordinator
  private unowned let factory: Factory
  typealias Factory = HasExternalPurchaseControllerFactory
    & OptionsFactory
    & TransactionManagerFactory
    & PurchasedTransactionsFactory

  // swiftlint:disable:next identifier_name
  var _sk2ObserverModePurchaseDetector: Any?
  @available(iOS 17.2, *)
  var sk2ObserverModePurchaseDetector: SK2ObserverModePurchaseDetector {
    // swiftlint:disable:next force_cast force_unwrapping
    return self._sk2ObserverModePurchaseDetector! as! SK2ObserverModePurchaseDetector
  }

  init(
    identityManager: IdentityManager,
    receiptManager: ReceiptManager,
    storage: Storage,
    coordinator: PurchasingCoordinator,
    factory: Factory
  ) {
    self.identityManager = identityManager
    self.receiptManager = receiptManager
    self.coordinator = coordinator
    self.factory = factory

    if #available(iOS 17.2, *) {
      _sk2ObserverModePurchaseDetector = SK2ObserverModePurchaseDetector(
        storage: storage,
        allTransactionsProvider: SK2AllTransactionsProvider(),
        factory: factory
      )

      // Cache legacy transactions if observer mode turned on.
      let options = factory.makeSuperwallOptions()
      if options.shouldObservePurchases {
        Task {
          await sk2ObserverModePurchaseDetector.cacheLegacyTransactions()
        }
      }
    }


    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleApplicationDidBecomeActive),
      name: SystemInfo.applicationDidBecomeActiveNotification,
      object: nil
    )
  }

  @objc
  private func handleApplicationDidBecomeActive() {
    let options = factory.makeSuperwallOptions()
    let shouldObservePurchases = options.shouldObservePurchases
    let storeKitVersion = options.storeKitVersion

    if shouldObservePurchases,
      storeKitVersion == .storeKit2,
      #available(iOS 17.2, visionOS 1.1, *) {
      Task(priority: .utility) { [weak self] in
        guard let self = self else {
          return
        }
        await self.sk2ObserverModePurchaseDetector.detectUnobservedTransactions(delegate: self)
      }
    }
  }

  func purchase(product: StoreProduct) async -> PurchaseResult {
    guard let product = product.sk2Product else {
      return .cancelled
    }
    do {
      var options: Set<StoreKit.Product.PurchaseOption> = []

      if let appAccountToken = identityManager.appAccountToken {
        options.insert(.appAccountToken(appAccountToken))
      }

      let result: StoreKit.Product.PurchaseResult

      #if os(visionOS)
      guard let sharedApplication = UIApplication.sharedApplication else {
        return .cancelled
      }
      guard let scene = await sharedApplication.connectedScenes.first else {
        return .cancelled
      }
      result = try await product.purchase(confirmIn: scene, options: options)
      #else
      result = try await product.purchase(options: options)
      #endif

      switch result {
      case let .success(.verified(transaction)):
        await transaction.finish()
        await receiptManager.loadPurchasedProducts()
        let result = PurchaseResult.purchased
        await coordinator.storeTransaction(transaction, result: result)
        return result
      case let .success(.unverified(transaction, error)):
        await transaction.finish()
        let result = PurchaseResult.failed(error)
        await coordinator.storeTransaction(transaction, result: result)
        return result
      case .userCancelled:
        return .cancelled
      case .pending:
        return .pending
      @unknown default:
        return .cancelled
      }
    } catch let error as StoreKitError {
      switch error {
      case .userCancelled:
        return .cancelled
      default:
        return .failed(error)
      }
    } catch {
      return .failed(error)
    }
  }

  func restorePurchases() async -> RestorationResult {
    var hasRestored = false
    var error: Error?

    for await verificationResult in StoreKit.Transaction.all {
      switch verificationResult {
      case .verified:
        hasRestored = true
      case .unverified(_, let transactionError):
        error = transactionError
      }
    }

    if hasRestored {
      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: "Restore Completed Transactions Finished"
      )
      return .restored
    } else {
      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: "Restore Completed Transactions Failed With Error",
        error: error
      )
      return .failed(error)
    }
  }
}

@available(iOS 17.2, visionOS 1.1, *)
extension ProductPurchaserSK2: SK2ObserverModePurchaseDetectorDelegate {
  func logSK2ObserverModeTransaction(_ transaction: SK2Transaction) async throws {
    let transactionManager = factory.makeTransactionManager()
    await transactionManager.logSK2ObserverModeTransaction(
      transaction
    )
  }
}
