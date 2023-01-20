//
//  File 2.swift
//  
//
//  Created by Yusuf Tör on 20/10/2022.
//

import StoreKit
import UIKit
import Combine

final class TransactionManager {
  private unowned let storeKitManager: StoreKitManager
  private unowned let sessionEventsManager: SessionEventsManager
  private let purchaseManager: PurchaseManager

  /// The paywall view controller that the last product was purchased from.
  private var lastPaywallViewController: PaywallViewController?

  init(
    storeKitManager: StoreKitManager,
    sessionEventsManager: SessionEventsManager
  ) {
    self.storeKitManager = storeKitManager
    self.sessionEventsManager = sessionEventsManager
    purchaseManager = PurchaseManager(storeKitManager: storeKitManager)
  }

  /// Purchases the given product and handles the result appropriately.
  ///
  /// - Parameters:
  ///   - productId: The ID of the product to purchase.
  ///   - paywallViewController: The `PaywallViewController` that the product is being
  ///   purhcased from.
  func purchase(
    _ productId: String,
    from paywallViewController: PaywallViewController
  ) async {
    guard let product = storeKitManager.productsById[productId] else {
      return
    }

    await prepareToStartTransaction(of: product, from: paywallViewController)

    let result = await purchaseManager.purchase(product: product)

    switch result {
    case .purchased(let transaction):
      await didPurchase(
        product,
        from: paywallViewController,
        transaction: transaction
      )
    case .failed(let error):
      let outcome = TransactionErrorLogic.handle(error)
      switch outcome {
      case .cancelled:
        await trackCancelled(
          product: product,
          from: paywallViewController
        )
      case .presentAlert:
        await presentAlert(
          forError: error,
          product: product,
          paywallViewController: paywallViewController
        )
      }
    case .pending:
      await handlePendingTransaction(from: paywallViewController)
    case .cancelled:
      await trackCancelled(product: product, from: paywallViewController)
    }
  }

  /// Cancels the transaction timeout when the application resigns active.
  ///
  /// When the purchase sheet appears, the application resigns active.

  // MARK: - Transaction lifecycle

  /// Tracks the analytics and logs the start of the transaction.
  private func prepareToStartTransaction(
    of product: StoreProduct,
    from paywallViewController: PaywallViewController
  ) async {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Transaction Purchasing",
      info: ["paywall_vc": paywallViewController],
      error: nil
    )

    let paywallInfo = await paywallViewController.paywallInfo
    Task.detached(priority: .utility) {
      await self.sessionEventsManager.triggerSession.trackBeginTransaction(of: product)
      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .start(product),
        paywallInfo: paywallInfo,
        product: product,
        model: nil
      )
      await Superwall.track(trackedEvent)
    }

    lastPaywallViewController = paywallViewController
    await MainActor.run {
      paywallViewController.loadingState = .loadingPurchase
    }
  }

  /// Dismisses the view controller, if the developer hasn't disabled the option.
  private func didPurchase(
    _ product: StoreProduct,
    from paywallViewController: PaywallViewController,
    transaction: StoreTransaction
  ) async {
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
    Task.detached(priority: .background) {
      await self.sessionEventsManager.enqueue(transaction)
    }
    await storeKitManager.loadPurchasedProducts()

    await trackTransactionDidSucceed(
      transaction,
      product: product
    )

    if Superwall.options.paywalls.automaticallyDismiss {
      await Superwall.shared.dismiss(
        paywallViewController,
        state: .purchased(productId: product.productIdentifier)
      )
    }
  }

  /// Track the cancelled
  private func trackCancelled(
    product: StoreProduct,
    from paywallViewController: PaywallViewController
  ) async {
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
      await self.sessionEventsManager.triggerSession.trackTransactionAbandon()
    }

    await MainActor.run {
      paywallViewController.loadingState = .ready
    }
  }

  private func handlePendingTransaction(from paywallViewController: PaywallViewController) async {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Transaction Pending",
      info: ["paywall_vc": paywallViewController],
      error: nil
    )

    let paywallInfo = await paywallViewController.paywallInfo
    Task.detached(priority: .utility) {
      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .fail(.pending("Needs parental approval")),
        paywallInfo: paywallInfo,
        product: nil,
        model: nil
      )
      await Superwall.track(trackedEvent)
      await self.sessionEventsManager.triggerSession.trackPendingTransaction()
    }

    await paywallViewController.presentAlert(
      title: "Waiting for Approval",
      message: "Thank you! This purchase is pending approval from your parent. Please try again once it is approved."
    )
  }

  private func presentAlert(
    forError error: Error,
    product: StoreProduct,
    paywallViewController: PaywallViewController
  ) async {
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

    let paywallInfo = await paywallViewController.paywallInfo
    Task.detached(priority: .utility) {
      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .fail(.failure(error.localizedDescription, product)),
        paywallInfo: paywallInfo,
        product: product,
        model: nil
      )
      await Superwall.track(trackedEvent)
      await self.sessionEventsManager.triggerSession.trackTransactionError()
    }

    await paywallViewController.presentAlert(
      title: "An error occurred",
      message: error.localizedDescription
    )
  }

  func trackTransactionDidSucceed(
    _ transaction: StoreTransaction,
    product: StoreProduct
  ) async {
    guard let paywallViewController = lastPaywallViewController else {
      return
    }

    let paywallShowingFreeTrial = await paywallViewController.paywall.isFreeTrialAvailable == true
    let didStartFreeTrial = product.hasFreeTrial && paywallShowingFreeTrial

    let paywallInfo = await paywallViewController.paywallInfo
    Task.detached(priority: .background) {
      await self.sessionEventsManager.triggerSession.trackTransactionSucceeded(
        withId: transaction.storeTransactionId,
        for: product,
        isFreeTrialAvailable: didStartFreeTrial
      )

      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .complete(product, transaction),
        paywallInfo: paywallInfo,
        product: product,
        model: transaction
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
    lastPaywallViewController = nil
  }
}
