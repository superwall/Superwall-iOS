//
//  File 2.swift
//  
//
//  Created by Yusuf Tör on 20/10/2022.
//
// swiftlint:disable type_body_length file_length line_length

import StoreKit
import UIKit
import Combine

final class TransactionManager {
  private let storeKitManager: StoreKitManager
  private let receiptManager: ReceiptManager
  private let purchaseController: PurchaseController
  private let sessionEventsManager: SessionEventsManager
  private let placementsQueue: PlacementsQueue
  private let factory: Factory
  typealias Factory = OptionsFactory
    & TriggerFactory
    & PurchasedTransactionsFactory
    & StoreTransactionFactory
    & DeviceHelperFactory

  init(
    storeKitManager: StoreKitManager,
    receiptManager: ReceiptManager,
    purchaseController: PurchaseController,
    sessionEventsManager: SessionEventsManager,
    placementsQueue: PlacementsQueue,
    factory: Factory
  ) {
    self.storeKitManager = storeKitManager
    self.receiptManager = receiptManager
    self.purchaseController = purchaseController
    self.sessionEventsManager = sessionEventsManager
    self.placementsQueue = placementsQueue
    self.factory = factory
  }

  /// Purchases the given product and handles the result appropriately.
  ///
  /// - Parameters:
  ///   - productId: The ID of the product to purchase.
  ///   - paywallViewController: The `PaywallViewController` that the product is being
  ///   purchased from.
  func purchase(
    _ productId: String,
    from paywallViewController: PaywallViewController
  ) async {
    guard let product = await storeKitManager.productsById[productId] else {
      Logger.debug(
        logLevel: .error,
        scope: .paywallTransactions,
        message: "Trying to purchase \(productId) but the product has failed to load. Visit https://superwall.com/l/missing-products to diagnose."
      )
      return
    }

    await prepareToStartTransaction(of: product, from: paywallViewController)

    let result = await purchase(product)

    switch result {
    case .purchased:
      await didPurchase(
        product,
        from: paywallViewController
      )
    case .restored:
      await didRestore(
        product: product,
        paywallViewController: paywallViewController
      )
    case .failed(let error):
      let superwallOptions = factory.makeSuperwallOptions()
      guard let outcome = TransactionErrorLogic.handle(
        error,
        triggers: factory.makeTriggers(),
        shouldShowPurchaseFailureAlert: superwallOptions.paywalls.shouldShowPurchaseFailureAlert
      ) else {
        await trackFailure(
          error: error,
          product: product,
          paywallViewController: paywallViewController
        )
        return await paywallViewController.togglePaywallSpinner(isHidden: true)
      }
      switch outcome {
      case .cancelled:
        await trackCancelled(
          product: product,
          from: paywallViewController
        )
      case .presentAlert:
        await trackFailure(
          error: error,
          product: product,
          paywallViewController: paywallViewController
        )
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

  @MainActor
  func tryToRestore(from paywallViewController: PaywallViewController) async {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Attempting Restore"
    )

    paywallViewController.loadingState = .loadingPurchase

    let restore = InternalSuperwallPlacement.Restore(
      state: .start,
      paywallInfo: paywallViewController.info
    )
    await Superwall.shared.track(restore)
    paywallViewController.webView.messageHandler.handle(.restoreStart)

    let restorationResult = await purchaseController.restorePurchases()

    let hasRestored = restorationResult == .restored
    let isUserSubscribed = Superwall.shared.subscriptionStatus == .active

    if hasRestored && isUserSubscribed {
      Logger.debug(
        logLevel: .debug,
        scope: .paywallTransactions,
        message: "Transactions Restored"
      )
      await didRestore(
        paywallViewController: paywallViewController
      )

      let trackedEvent = InternalSuperwallPlacement.Restore(
        state: .complete,
        paywallInfo: paywallViewController.info
      )
      await Superwall.shared.track(trackedEvent)
      paywallViewController.webView.messageHandler.handle(.restoreComplete)
    } else {
      var message = "Transactions Failed to Restore."

      if !isUserSubscribed && hasRestored {
        message += " The user's subscription status is \"inactive\", but the restoration result is \"restored\". Ensure the subscription status is active before confirming successful restoration."
      }
      if case .failed(let error) = restorationResult,
        let error = error {
        message += " Original restoration error message: \(error.safeLocalizedDescription)"
      }

      Logger.debug(
        logLevel: .debug,
        scope: .paywallTransactions,
        message: message
      )

      let trackedEvent = InternalSuperwallPlacement.Restore(
        state: .fail(message),
        paywallInfo: paywallViewController.info
      )
      await Superwall.shared.track(trackedEvent)
      paywallViewController.webView.messageHandler.handle(.restoreFail(message))

      paywallViewController.presentAlert(
        title: Superwall.shared.options.paywalls.restoreFailed.title,
        message: Superwall.shared.options.paywalls.restoreFailed.message,
        closeActionTitle: Superwall.shared.options.paywalls.restoreFailed.closeButtonTitle
      )
    }
  }

  private func didRestore(
    product: StoreProduct? = nil,
    paywallViewController: PaywallViewController
  ) async {
    let purchasingCoordinator = factory.makePurchasingCoordinator()
    var transaction: StoreTransaction?
    let restoreType: RestoreType

    if let product = product {
      // Product exists so much have been via a purchase of a specific product.
      transaction = await purchasingCoordinator.getLatestTransaction(
        forProductId: product.productIdentifier,
        factory: factory
      )
      restoreType = .viaPurchase(transaction)
    } else {
      // Otherwise it was a generic restore.
      restoreType = .viaRestore
    }

    let paywallInfo = await paywallViewController.info

    let trackedEvent = InternalSuperwallPlacement.Transaction(
      state: .restore(restoreType),
      paywallInfo: paywallInfo,
      product: product,
      model: transaction
    )
    await Superwall.shared.track(trackedEvent)
    await paywallViewController.webView.messageHandler.handle(.transactionRestore)

    let superwallOptions = factory.makeSuperwallOptions()
    if superwallOptions.paywalls.automaticallyDismiss {
      await Superwall.shared.dismiss(paywallViewController, result: .restored)
    }
  }

  private func purchase(_ product: StoreProduct) async -> PurchaseResult {
    guard let sk1Product = product.sk1Product else {
      return .failed(PurchaseError.productUnavailable)
    }
    await factory.makePurchasingCoordinator().beginPurchase(
      of: product.productIdentifier
    )
    return await purchaseController.purchase(product: sk1Product)
  }

  /// Cancels the transaction timeout when the application resigns active.
  ///
  /// When the purchase sheet appears, the application resigns active.

  // MARK: - Transaction lifecycle

  private func trackFailure(
    error: Error,
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

    let paywallInfo = await paywallViewController.info
    Task {
      let trackedEvent = InternalSuperwallPlacement.Transaction(
        state: .fail(.failure(error.safeLocalizedDescription, product)),
        paywallInfo: paywallInfo,
        product: product,
        model: nil
      )
      await Superwall.shared.track(trackedEvent)
      await paywallViewController.webView.messageHandler.handle(.transactionFail)
    }
  }

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

    let paywallInfo = await paywallViewController.info

    let trackedEvent = InternalSuperwallPlacement.Transaction(
      state: .start(product),
      paywallInfo: paywallInfo,
      product: product,
      model: nil
    )
    await Superwall.shared.track(trackedEvent)
    await paywallViewController.webView.messageHandler.handle(.transactionStart)

    await MainActor.run {
      paywallViewController.loadingState = .loadingPurchase
    }
  }

  /// Dismisses the view controller, if the developer hasn't disabled the option.
  private func didPurchase(
    _ product: StoreProduct,
    from paywallViewController: PaywallViewController
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

    let purchasingCoordinator = factory.makePurchasingCoordinator()
    let transaction = await purchasingCoordinator.getLatestTransaction(
      forProductId: product.productIdentifier,
      factory: factory
    )

    if let transaction = transaction {
      await self.sessionEventsManager.enqueue(transaction)
    }

    await receiptManager.loadPurchasedProducts()

    await trackTransactionDidSucceed(
      transaction,
      product: product,
      paywallViewController: paywallViewController
    )

    let superwallOptions = factory.makeSuperwallOptions()
    if superwallOptions.paywalls.automaticallyDismiss {
      await Superwall.shared.dismiss(
        paywallViewController,
        result: .purchased(productId: product.productIdentifier)
      )
    }
  }

  /// Track the cancelled
  private func trackCancelled(
    product: StoreProduct,
    from paywallViewController: PaywallViewController
  ) async {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Transaction Abandoned",
      info: ["product_id": product.productIdentifier, "paywall_vc": paywallViewController],
      error: nil
    )

    let paywallInfo = await paywallViewController.info
    let trackedEvent = InternalSuperwallPlacement.Transaction(
      state: .abandon(product),
      paywallInfo: paywallInfo,
      product: product,
      model: nil
    )
    await Superwall.shared.track(trackedEvent)
    await paywallViewController.webView.messageHandler.handle(.transactionAbandon)

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

    let paywallInfo = await paywallViewController.info

    let trackedEvent = InternalSuperwallPlacement.Transaction(
      state: .fail(.pending("Needs parental approval")),
      paywallInfo: paywallInfo,
      product: nil,
      model: nil
    )
    await Superwall.shared.track(trackedEvent)
    await paywallViewController.webView.messageHandler.handle(.transactionFail)

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
    await paywallViewController.presentAlert(
      title: "An error occurred",
      message: error.safeLocalizedDescription
    )
  }

  func trackTransactionDidSucceed(
    _ transaction: StoreTransaction?,
    product: StoreProduct,
    paywallViewController: PaywallViewController
  ) async {
    let paywallShowingFreeTrial = await paywallViewController.paywall.isFreeTrialAvailable == true
    let didStartFreeTrial = product.hasFreeTrial && paywallShowingFreeTrial

    let paywallInfo = await paywallViewController.info

    let trackedEvent = InternalSuperwallPlacement.Transaction(
      state: .complete(product, transaction),
      paywallInfo: paywallInfo,
      product: product,
      model: transaction
    )
    await Superwall.shared.track(trackedEvent)
    await paywallViewController.webView.messageHandler.handle(.transactionComplete)

    // Immediately flush the events queue on transaction complete.
    await placementsQueue.flushInternal()

    if product.subscriptionPeriod == nil {
      let trackedEvent = InternalSuperwallPlacement.NonRecurringProductPurchase(
        paywallInfo: paywallInfo,
        product: product
      )
      await Superwall.shared.track(trackedEvent)
    } else {
      if didStartFreeTrial {
        let trackedEvent = InternalSuperwallPlacement.FreeTrialStart(
          paywallInfo: paywallInfo,
          product: product
        )
        await Superwall.shared.track(trackedEvent)

        let notifications = paywallInfo.localNotifications.filter {
          $0.type == .trialStarted
        }

        await NotificationScheduler.scheduleNotifications(notifications, factory: factory)
      } else {
        let trackedEvent = InternalSuperwallPlacement.SubscriptionStart(
          paywallInfo: paywallInfo,
          product: product
        )
        await Superwall.shared.track(trackedEvent)
      }
    }
  }
}
