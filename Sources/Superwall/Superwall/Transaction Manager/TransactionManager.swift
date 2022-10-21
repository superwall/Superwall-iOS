//
//  File 2.swift
//  
//
//  Created by Yusuf Tör on 20/10/2022.
//

import StoreKit
import UIKit

@MainActor
final class TransactionManager {
  private var sk1TransactionObserver: Sk1TransactionObserver?
  // Can't have these properties with `@available`.
  // swiftlint:disable identifier_name
  private var _sk2TransactionObserver: Any?
  // swiftlint:enable identifier_name

  /// Handles restoration logic
  lazy var restorationHandler = RestorationHandler()

  /*
  var _storeKit2StorefrontListener: Any?
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  var storeKit2StorefrontListener: Sk2StorefrontListener {
      // swiftlint:disable:next force_cast
      return self._storeKit2StorefrontListener! as! StoreKit2StorefrontListener
  }
   */

  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  var sk2TransactionObserver: Sk2TransactionObserver {
      // swiftlint:disable:next force_cast
      return self._sk2TransactionObserver! as! Sk2TransactionObserver
  }

  init() {
    // If iOS 15 is available, we can just rely on the SK2 transaction observer
    // for all transactions. Otherwise we fall back to the SK1 transaction observer.
    if #available(iOS 15.0, *) {
      self._sk2TransactionObserver = Sk2TransactionObserver()
    } else {
      sk1TransactionObserver = Sk1TransactionObserver()
    }
  }

  func purchase(
    _ productId: String,
    from paywallViewController: PaywallViewController
  ) async {
    guard let product = StoreKitManager.shared.productsById[productId] else {
      return
    }
    trackTransactionStart(of: product, from: paywallViewController)

    paywallViewController.loadingState = .loadingPurchase
    paywallViewController.showRefreshButtonAfterTimeout(false)

    do {
      let result = try await Superwall.shared.delegateManager.purchase(product: product)
      switch result {
      case .purchased:
        didPurchase(product, from: paywallViewController)
      case .pending:
        handleTransactionPending(paywallViewController: paywallViewController)
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

  /// Tracks the analytics and logs the start of the transaction.
  private func trackTransactionStart(
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
        state: .start,
        paywallInfo: paywallInfo,
        product: product
      )
      await Superwall.track(trackedEvent)
    }
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
        state: .abandon,
        paywallInfo: paywallInfo,
        product: product
      )
      await Superwall.track(trackedEvent)
      await SessionEventsManager.shared.triggerSession.trackTransactionAbandon()
    }
  }

  private func handleTransactionPending(
    paywallViewController: PaywallViewController
  ) {
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
        state: .fail(message: "Needs parental approval"),
        paywallInfo: paywallInfo,
        product: nil
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
        state: .fail(message: error.localizedDescription),
        paywallInfo: paywallInfo,
        product: product
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
