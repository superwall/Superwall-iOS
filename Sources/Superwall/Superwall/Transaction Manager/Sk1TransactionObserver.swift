//
//  File.swift
//  
//
//  Created by Jake Mor on 11/16/21.
//
// swiftlint:disable trailing_closure function_body_length

import Foundation
import StoreKit

protocol TransactionObserverDelegate: AnyObject {
  func hi()
}

final class Sk1TransactionObserver: NSObject {
  weak var delegate: TransactionObserverDelegate?

  override init() {
    super.init()
    SKPaymentQueue.default().add(self)
  }

  private func trackTransactionDidSucceed(
    withId id: String?,
    paywallViewController: PaywallViewController,
    for product: SKProduct
  ) async {
    let isFreeTrialAvailable = await paywallViewController.paywall.isFreeTrialAvailable == true

    await SessionEventsManager.shared.triggerSession.trackTransactionSucceeded(
      withId: id,
      for: product,
      isFreeTrialAvailable: isFreeTrialAvailable
    )

    let paywallInfo = await paywallViewController.paywallInfo
    let trackedEvent = InternalSuperwallEvent.Transaction(
      state: .complete,
      paywallInfo: paywallInfo,
      product: product
    )
    await Superwall.track(trackedEvent)

    if product.subscriptionPeriod == nil {
      let trackedEvent = InternalSuperwallEvent.NonRecurringProductPurchase(
        paywallInfo: paywallInfo,
        product: product
      )
      await Superwall.track(trackedEvent)
    }

    if isFreeTrialAvailable {
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
}

// MARK: - SKPaymentTransactionObserver
extension Sk1TransactionObserver: SKPaymentTransactionObserver {
	public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
		Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Restore Completed Transactions Finished",
      info: nil,
      error: nil
    )
	}

	public func paymentQueue(
    _ queue: SKPaymentQueue,
    restoreCompletedTransactionsFailedWithError error: Error
  ) {
		Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Restore Completed Transactions Failed With Error",
      info: nil,
      error: error
    )
	}

  // TODO: Remove MainActor?
  @MainActor
	public func paymentQueue(
    _ queue: SKPaymentQueue,
    updatedTransactions transactions: [SKPaymentTransaction]
  ) {
		for transaction in transactions {
      Task.detached(priority: .utility) {
        await SessionEventsManager.shared
          .transactionRecorder
          .record(transaction)
      }

      // TODO: DOUBLE CHECK THIS:
      guard Superwall.shared.paywallWasPresentedThisSession else {
        return
      }
      guard let paywallViewController = Superwall.shared.paywallViewController else {
        return
      }
			guard let product = StoreKitManager.shared.productsById[transaction.payment.productIdentifier] else {
        return
      }

			switch transaction.transactionState {
			case .purchased:
        Task.detached(priority: .utility) {
          await self.trackTransactionDidSucceed(
            withId: transaction.transactionIdentifier,
            paywallViewController: paywallViewController,
            for: product
          )
        }
			case .restored:
        let isFreeTrialAvailable = paywallViewController.paywall.isFreeTrialAvailable == true
        Task.detached(priority: .utility) {
          await SessionEventsManager.shared.triggerSession.trackTransactionRestoration(
            withId: transaction.transactionIdentifier,
            product: product,
            isFreeTrialAvailable: isFreeTrialAvailable
          )
        }
			case .deferred,
        .failed,
        .purchasing:
        break
			default:
				break
			}
		}
	}
}
