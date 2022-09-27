//
//  File.swift
//  
//
//  Created by Jake Mor on 11/16/21.
//
// swiftlint:disable trailing_closure function_body_length

import Foundation
import StoreKit

extension Paywall {
  func tryToRestore(
    _ paywallViewController: SWPaywallViewController,
    userInitiated: Bool = false
  ) {
    onMain {
      Logger.debug(
        logLevel: .debug,
        scope: .paywallTransactions,
        message: "Attempting Restore"
      )
      guard let delegate = Paywall.delegate else {
        return
      }
      if userInitiated {
        paywallViewController.loadingState = .loadingPurchase
      }

      delegate.restorePurchases { [weak self] success in
        onMain {
          if userInitiated {
            paywallViewController.loadingState = .ready
          }
          if success {
            Logger.debug(
              logLevel: .debug,
              scope: .paywallTransactions,
              message: "Transaction Restored"
            )
            self?.transactionWasRestored(paywallViewController: paywallViewController)
          } else {
            // TODO: We're not tracking restoration failures?
            Logger.debug(
              logLevel: .debug,
              scope: .paywallTransactions,
              message: "Transaction Failed to Restore"
            )
            if userInitiated {
              paywallViewController.presentAlert(
                title: Paywall.options.restoreFailed.title,
                message: Paywall.options.restoreFailed.message,
                closeActionTitle: Paywall.options.restoreFailed.closeButtonTitle
              )
            }
          }
        }
      }
    }
  }

	// purchase callbacks
	private func transactionDidBegin(
    paywallViewController: SWPaywallViewController,
    for product: SKProduct
  ) {
    SessionEventsManager.shared.triggerSession.trackBeginTransaction(of: product)

		let paywallInfo = paywallViewController.paywallInfo
    let trackedEvent = InternalSuperwallEvent.Transaction(
      state: .start,
      paywallInfo: paywallInfo,
      product: product
    )
    Paywall.track(trackedEvent)

		paywallViewController.loadingState = .loadingPurchase

		onMain {
			paywallViewController.showRefreshButtonAfterTimeout(false)
		}
	}

	private func transactionDidSucceed(
    withId id: String?,
    paywallViewController: SWPaywallViewController,
    for product: SKProduct
  ) {
    let isFreeTrialAvailable = paywallViewController.paywallResponse.isFreeTrialAvailable == true

    SessionEventsManager.shared.triggerSession.trackTransactionSucceeded(
      withId: id,
      for: product,
      isFreeTrialAvailable: isFreeTrialAvailable
    )

    let paywallInfo = paywallViewController.paywallInfo
    let trackedEvent = InternalSuperwallEvent.Transaction(
      state: .complete,
      paywallInfo: paywallInfo,
      product: product
    )
    Paywall.track(trackedEvent)

    if product.subscriptionPeriod == nil {
      let trackedEvent = InternalSuperwallEvent.NonRecurringProductPurchase(
        paywallInfo: paywallInfo,
        product: product
      )
      Paywall.track(trackedEvent)
    }

    if isFreeTrialAvailable {
      let trackedEvent = InternalSuperwallEvent.FreeTrialStart(
        paywallInfo: paywallInfo,
        product: product
      )
      Paywall.track(trackedEvent)
    } else {
      let trackedEvent = InternalSuperwallEvent.SubscriptionStart(
        paywallInfo: paywallInfo,
        product: product
      )
      Paywall.track(trackedEvent)
    }

    if Paywall.options.automaticallyDismiss {
      dismiss(
        paywallViewController,
        state: .purchased(productId: product.productIdentifier)
      )
    } else {
      paywallViewController.loadingState = .ready
    }
	}

  @MainActor
	private func transactionErrorDidOccur(
    paywallViewController: SWPaywallViewController,
    error: SKError?,
    for product: SKProduct
  ) {
    paywallViewController.loadingState = .ready

    if didTryToAutoRestore {
      paywallViewController.loadingState = .ready

      let paywallInfo = paywallViewController.paywallInfo
      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .fail(message: error?.localizedDescription ?? ""),
        paywallInfo: paywallInfo,
        product: product
      )
      Paywall.track(trackedEvent)

      SessionEventsManager.shared.triggerSession.trackTransactionError()

      self.paywallViewController?.presentAlert(
        title: "Please try again",
        message: error?.localizedDescription ?? "",
        actionTitle: "Restore Purchase",
        onCancel: {
          Paywall.shared.tryToRestore(paywallViewController)
        }
      )
    } else {
      Paywall.shared.tryToRestore(paywallViewController)
      didTryToAutoRestore = true
    }
	}

	private func transactionWasAbandoned(
    paywallViewController: SWPaywallViewController,
    for product: SKProduct
  ) {
		let paywallInfo = paywallViewController.paywallInfo
    let trackedEvent = InternalSuperwallEvent.Transaction(
      state: .abandon,
      paywallInfo: paywallInfo,
      product: product
    )
    Paywall.track(trackedEvent)

    SessionEventsManager.shared.triggerSession.trackTransactionAbandon()

		paywallViewController.loadingState = .ready
	}

	private func transactionWasRestored(paywallViewController: SWPaywallViewController) {
		let paywallInfo = paywallViewController.paywallInfo
    let trackedEvent = InternalSuperwallEvent.Transaction(
      state: .restore,
      paywallInfo: paywallInfo,
      product: nil
    )
    Paywall.track(trackedEvent)

    if Paywall.options.automaticallyDismiss {
      dismiss(paywallViewController, state: .restored)
    } else {
      paywallViewController.loadingState = .ready
    }
	}

	// if a parent needs to approve the purchase
	private func transactionWasDeferred(paywallViewController: SWPaywallViewController) {
		paywallViewController.presentAlert(
      title: "Waiting for Approval",
      message: "Thank you! This purchase is pending approval from your parent. Please try again once it is approved."
    )

		let paywallInfo = paywallViewController.paywallInfo
    let trackedEvent = InternalSuperwallEvent.Transaction(
      state: .fail(message: "Needs parental approval"),
      paywallInfo: paywallInfo,
      product: nil
    )
    Paywall.track(trackedEvent)

    SessionEventsManager.shared.triggerSession.trackDeferredTransaction()
	}
}

// MARK: - SKPaymentTransactionObserver
extension Paywall: SKPaymentTransactionObserver {
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

  @MainActor
	public func paymentQueue(
    _ queue: SKPaymentQueue,
    updatedTransactions transactions: [SKPaymentTransaction]
  ) {
		for transaction in transactions {
      SessionEventsManager.shared.transactions.record(transaction)

			guard paywallWasPresentedThisSession else {
        return
      }
			guard let paywallViewController = paywallViewController else {
        return
      }
			guard let product = StoreKitManager.shared.productsById[transaction.payment.productIdentifier] else {
        return
      }

			switch transaction.transactionState {
			case .purchased:
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
				transactionDidSucceed(
          withId: transaction.transactionIdentifier,
          paywallViewController: paywallViewController,
          for: product
        )
			case .failed:
				if let error = transaction.error as? SKError {
					var userCancelled = error.code == .overlayCancelled || error.code == .paymentCancelled

					if #available(iOS 14.0, *) {
            userCancelled = error.code == .overlayCancelled
              || error.code == .paymentCancelled
              || error.code == .overlayTimeout
					}

					if userCancelled {
						Logger.debug(
              logLevel: .debug,
              scope: .paywallTransactions,
              message: "Transaction Abandoned",
              info: ["product_id": product.productIdentifier, "paywall_vc": paywallViewController],
              error: nil
            )
						transactionWasAbandoned(paywallViewController: paywallViewController, for: product)
						return
					} else {
						Logger.debug(
              logLevel: .debug,
              scope: .paywallTransactions,
              message: "Transaction Error",
              info: ["product_id": product.productIdentifier, "paywall_vc": paywallViewController],
              error: error
            )
						transactionErrorDidOccur(paywallViewController: paywallViewController, error: error, for: product)
						return
					}
				} else {
					Logger.debug(
            logLevel: .debug,
            scope: .paywallTransactions,
            message: "Transaction Error",
            info: [
              "product_id": product.productIdentifier,
              "paywall_vc": paywallViewController
            ],
            error: transaction.error
          )
					self.transactionErrorDidOccur(paywallViewController: paywallViewController, error: nil, for: product)
					onMain {
						paywallViewController.presentAlert(
              title: "Something went wrong",
              message: transaction.error?.localizedDescription ?? "",
              actionTitle: nil,
              action: nil
            )
					}
				}
			case .restored:
        let isFreeTrialAvailable = paywallViewController.paywallResponse.isFreeTrialAvailable == true
        SessionEventsManager.shared.triggerSession.trackTransactionRestoration(
          withId: transaction.transactionIdentifier,
          product: product,
          isFreeTrialAvailable: isFreeTrialAvailable
        )
			case .deferred:
				Logger.debug(
          logLevel: .debug,
          scope: .paywallTransactions,
          message: "Transaction Deferred",
          info: ["paywall_vc": paywallViewController],
          error: nil
        )
				transactionWasDeferred(paywallViewController: paywallViewController)
			case .purchasing:
				Logger.debug(
          logLevel: .debug,
          scope: .paywallTransactions,
          message: "Transaction Purchasing",
          info: ["paywall_vc": paywallViewController],
          error: nil
        )
				transactionDidBegin(paywallViewController: paywallViewController, for: product)
			default:
				paywallViewController.loadingState = .ready
			}
		}
	}
}
