//
//  File 2.swift
//  
//
//  Created by Yusuf Tör on 20/10/2022.
//

import StoreKit
import UIKit
import Combine

@MainActor
final class TransactionManager {
  /// Sends all transactions back to the server.
  lazy var transactionRecorder = TransactionRecorder()

  /// The StoreKit 1 transaction observer.
  private var sk1TransactionObserver: Sk1TransactionObserver?

  /// The StoreKit 2 transaction observer.
  ///
  /// This has to be `Any` as we can't restrict stored properties to
  /// an iOS version with`@available`.
  private var _sk2TransactionObserver: Any?

  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  private var sk2TransactionObserver: Sk2TransactionObserver {
    // swiftlint:disable:next force_cast force_unwrapping
    return _sk2TransactionObserver! as! Sk2TransactionObserver
  }

  /// The paywall view controller that the last product was purchased from.
  private var lastPaywallViewController: PaywallViewController?

  /// The last product purchased.
  private var lastProductPurchased: SKProduct?

  init() {
    if #available(iOS 15.0, *) {
      self._sk2TransactionObserver = Sk2TransactionObserver(delegate: self)
    } else {
      sk1TransactionObserver = Sk1TransactionObserver(delegate: self)
    }
  }

  /// Purchases the given product and handles the callback appropriately.
  ///
  /// - Parameters:
  ///   - productId: The ID of the product to purchase.
  ///   - paywallViewController: The `PaywallViewController` that the product is being
  ///   purhcased from.
  func purchase(
    _ productId: String,
    from paywallViewController: PaywallViewController
  ) async {
    guard let product = StoreKitManager.shared.productsById[productId] else {
      return
    }
    prepareToStartTransaction(of: product, from: paywallViewController)

    do {
      let purchaseStartDate = Date()

      paywallViewController.startTransactionTimeout()
      let result = try await Superwall.shared.delegateAdapter.purchase(product: product)
      paywallViewController.cancelTransactionTimeout()

      if #available(iOS 15.0, *) {
        await checkForTransaction(of: product, since: purchaseStartDate)
      }

      switch result {
      case .purchased:
        didPurchase(product, from: paywallViewController)
      case .pending:
        handlePendingTransaction(from: paywallViewController)
      case .cancelled:
        trackCancelled(product: product, from: paywallViewController)
      }
    } catch {
      let outcome = TransactionErrorLogic.handle(error)
      switch outcome {
      case .cancelled:
        trackCancelled(
          product: product,
          from: paywallViewController
        )
      case .presentAlert:
        presentAlert(
          forError: error,
          product: product,
          paywallViewController: paywallViewController
        )
      }
    }

    paywallViewController.loadingState = .ready
  }

  /// Cancels the transaction timeout when the application resigns active.
  ///
  /// When the purchase sheet appears, the application resigns active.


  // MARK: - Transaction lifecycle

  /// Tracks the analytics and logs the start of the transaction.
  private func prepareToStartTransaction(
    of product: SKProduct,
    from paywallViewController: PaywallViewController
  ) {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Transaction Purchasing",
      info: ["paywall_vc": paywallViewController],
      error: nil
    )

    let paywallInfo = paywallViewController.paywallInfo
    Task.detached(priority: .utility) {
      await SessionEventsManager.shared.triggerSession.trackBeginTransaction(of: product)
      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .start(product),
        paywallInfo: paywallInfo,
        product: product,
        model: nil
      )
      await Superwall.track(trackedEvent)
    }

    lastProductPurchased = product
    lastPaywallViewController = paywallViewController
    paywallViewController.loadingState = .loadingPurchase
  }

  /// An iOS 15-only function that checks for a transaction of the product.
  ///
  /// We need this function because on iOS 15+, the `Transaction.updates` listener doesn't notify us
  /// of transactions for recent purchases.
  @available(iOS 15.0, *)
  private func checkForTransaction(
    of product: SKProduct,
    since purchaseStartDate: Date
  ) async {
    let transaction = await Transaction.latest(for: product.productIdentifier)
    guard case let .verified(transaction) = transaction else {
      return
    }
    guard transaction.purchaseDate >= purchaseStartDate else {
      return
    }

    let transactionModel = await transactionRecorder.record(transaction)

    await self.trackTransactionDidSucceed(
      transactionModel,
      product: product
    )
  }

  /// Dismisses the view controller, if the developer hasn't disabled the option.
  private func didPurchase(
    _ product: SKProduct,
    from paywallViewController: PaywallViewController
  ) {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Transaction Succeeded",
      info: [
        "product_id": product.productIdentifier,
        "paywall_vc": paywallViewController
      ],
      error: nil
    )
    guard Superwall.options.paywalls.automaticallyDismiss else {
      return
    }
    Superwall.shared.dismiss(
      paywallViewController,
      state: .purchased(productId: product.productIdentifier)
    )
  }

  /// Track the cancelled
  private func trackCancelled(
    product: SKProduct,
    from paywallViewController: PaywallViewController
  ) {
    Task.detached(priority: .utility) {
      Logger.debug(
        logLevel: .debug,
        scope: .paywallTransactions,
        message: "Transaction Abandoned",
        info: ["product_id": product.productIdentifier, "paywall_vc": paywallViewController],
        error: nil
      )

      let paywallInfo = await paywallViewController.paywallInfo
      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .abandon(product),
        paywallInfo: paywallInfo,
        product: product,
        model: nil
      )
      await Superwall.track(trackedEvent)
      await SessionEventsManager.shared.triggerSession.trackTransactionAbandon()
    }
  }

  private func handlePendingTransaction(from paywallViewController: PaywallViewController) {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Transaction Pending",
      info: ["paywall_vc": paywallViewController],
      error: nil
    )

    let paywallInfo = paywallViewController.paywallInfo
    Task.detached(priority: .utility) {
      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .fail(.pending("Needs parental approval")),
        paywallInfo: paywallInfo,
        product: nil,
        model: nil
      )
      await Superwall.track(trackedEvent)
      await SessionEventsManager.shared.triggerSession.trackDeferredTransaction()
    }

    paywallViewController.presentAlert(
      title: "Waiting for Approval",
      message: "Thank you! This purchase is pending approval from your parent. Please try again once it is approved."
    )
  }

  private func presentAlert(
    forError error: Error,
    product: SKProduct,
    paywallViewController: PaywallViewController
  ) {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Transaction Error",
      info: [
        "product_id": product.productIdentifier,
        "paywall_vc": paywallViewController
      ],
      error: error
    )

    let paywallInfo = paywallViewController.paywallInfo
    Task.detached(priority: .utility) {
      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .fail(.failure(error.localizedDescription, product)),
        paywallInfo: paywallInfo,
        product: product,
        model: nil
      )
      await Superwall.track(trackedEvent)
      await SessionEventsManager.shared.triggerSession.trackTransactionError()
    }

    paywallViewController.presentAlert(
      title: "An error occurred",
      message: error.localizedDescription
    )
  }
}

// MARK: - Transaction Observer Delegate
extension TransactionManager: TransactionObserverDelegate {
  func trackTransactionRestoration(
    withId transactionId: String?,
    product: SKProduct
  ) async {
    guard let paywallViewController = lastPaywallViewController else {
      return
    }

    let paywallShowingFreeTrial = paywallViewController.paywall.isFreeTrialAvailable == true
    let didStartFreeTrial = product.hasFreeTrial && paywallShowingFreeTrial

    await SessionEventsManager.shared.triggerSession.trackTransactionRestoration(
      withId: transactionId,
      product: product,
      isFreeTrialAvailable: didStartFreeTrial
    )
  }

  func trackTransactionDidSucceed(
    _ transactionModel: TransactionModel,
    product: SKProduct
  ) async {
    guard lastProductPurchased == product else {
      return
    }
    guard let paywallViewController = lastPaywallViewController else {
      return
    }

    let paywallShowingFreeTrial = paywallViewController.paywall.isFreeTrialAvailable == true
    let didStartFreeTrial = product.hasFreeTrial && paywallShowingFreeTrial

    let paywallInfo = paywallViewController.paywallInfo
    Task.detached(priority: .utility) {
      await SessionEventsManager.shared.triggerSession.trackTransactionSucceeded(
        withId: transactionModel.storeTransactionId,
        for: product,
        isFreeTrialAvailable: didStartFreeTrial
      )

      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .complete(product, transactionModel),
        paywallInfo: paywallInfo,
        product: product,
        model: transactionModel
      )
      await Superwall.track(trackedEvent)

      if product.subscriptionPeriod == nil {
        let trackedEvent = InternalSuperwallEvent.NonRecurringProductPurchase(
          paywallInfo: paywallInfo,
          product: product
        )
        await Superwall.track(trackedEvent)
      }

      if didStartFreeTrial {
        let trackedEvent = InternalSuperwallEvent.FreeTrialStart(
          paywallInfo: paywallInfo,
          product: product
        )
        await Superwall.track(trackedEvent)
      } else {
        let trackedEvent = InternalSuperwallEvent.SubscriptionStart(
          paywallInfo: paywallInfo,
          product: product
        )
        await Superwall.track(trackedEvent)
      }
    }

    lastProductPurchased = nil
    lastPaywallViewController = nil
  }
}
