//
//  File.swift
//  
//
//  Created by Jake Mor on 11/16/21.
//

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
            Logger.debug(
              logLevel: .debug,
              scope: .paywallTransactions,
              message: "Transaction Failed to Restore"
            )
            if userInitiated {
              paywallViewController.presentAlert(
                title: Paywall.restoreFailedTitleString,
                message: Paywall.restoreFailedMessageString,
                closeActionTitle: Paywall.restoreFailedCloseButtonString
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
		if let paywallInfo = paywallViewController.paywallInfo {
      let trackedEvent = SuperwallEvent.Transaction(
        state: .start,
        paywallInfo: paywallInfo,
        product: product
      )
			Paywall.track(trackedEvent)
		}

		paywallViewController.loadingState = .loadingPurchase

		onMain {
			paywallViewController.showRefreshButtonAfterTimeout(show: false)
		}
	}

	private func transactionDidSucceed(
    paywallViewController: SWPaywallViewController,
    for product: SKProduct
  ) {
    if let paywallInfo = paywallViewController.paywallInfo {
      let trackedEvent = SuperwallEvent.Transaction(
        state: .complete,
        paywallInfo: paywallInfo,
        product: product
      )
      Paywall.track(trackedEvent)

      if product.subscriptionPeriod == nil {
        let trackedEvent = SuperwallEvent.NonRecurringProductPurchase(
          paywallInfo: paywallInfo,
          product: product
        )
        Paywall.track(trackedEvent)
      }

			if let freeTrialAvailable = paywallViewController.paywallResponse?.isFreeTrialAvailable {
				if freeTrialAvailable {
          let trackedEvent = SuperwallEvent.FreeTrialStart(
            paywallInfo: paywallInfo,
            product: product
          )
          Paywall.track(trackedEvent)
				} else {
          let trackedEvent = SuperwallEvent.SubscriptionStart(
            paywallInfo: paywallInfo,
            product: product
          )
          Paywall.track(trackedEvent)
				}
			}
		}
    dismiss(
      paywallViewController,
      state: .purchased(productId: product.productIdentifier)
    )
	}

	private func transactionErrorDidOccur(
    paywallViewController: SWPaywallViewController,
    error: SKError?,
    for product: SKProduct
  ) {
		// prevent a recursive loop
		onMain { [weak self] in
			guard let self = self else {
        return
      }
			paywallViewController.loadingState = .ready

			if self.didTryToAutoRestore {
				paywallViewController.loadingState = .ready

				if let paywallInfo = paywallViewController.paywallInfo {
          let trackedEvent = SuperwallEvent.Transaction(
            state: .fail(message: error?.localizedDescription ?? ""),
            paywallInfo: paywallInfo,
            product: product
          )
					Paywall.track(trackedEvent)
				}

				self.paywallViewController?.presentAlert(
          title: "Please try again",
          message: error?.localizedDescription ?? "",
          actionTitle: "Restore Purchase"
        ) {
					Paywall.shared.tryToRestore(paywallViewController)
				}
      } else {
        Paywall.shared.tryToRestore(paywallViewController)
        self.didTryToAutoRestore = true
      }
		}
	}

	private func transactionWasAbandoned(
    paywallViewController: SWPaywallViewController,
    for product: SKProduct
  ) {
		if let paywallInfo = paywallViewController.paywallInfo {
      let trackedEvent = SuperwallEvent.Transaction(
        state: .abandon,
        paywallInfo: paywallInfo,
        product: product
      )
      Paywall.track(trackedEvent)
		}

		paywallViewController.loadingState = .ready
	}

	private func transactionWasRestored(paywallViewController: SWPaywallViewController) {
		if let paywallInfo = paywallViewController.paywallInfo {
      let trackedEvent = SuperwallEvent.Transaction(
        state: .restore,
        paywallInfo: paywallInfo,
        product: nil
      )
			Paywall.track(trackedEvent)
		}
    dismiss(paywallViewController, state: .restored)
	}

	// if a parent needs to approve the purchase
	private func transactionWasDeferred(paywallViewController: SWPaywallViewController) {
		paywallViewController.presentAlert(
      title: "Waiting for Approval",
      message: "Thank you! This purchase is pending approval from your parent. Please try again once it is approved."
    )

		if let paywallInfo = paywallViewController.paywallInfo {
      let trackedEvent = SuperwallEvent.Transaction(
        state: .fail(message: "Needs parental approval"),
        paywallInfo: paywallInfo,
        product: nil
      )
      Paywall.track(trackedEvent)
		}
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

	public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
		Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Restore Completed Transactions Failed With Error",
      info: nil,
      error: error
    )
	}

  // swiftlint:disable:next function_body_length
	public func paymentQueue(
    _ queue: SKPaymentQueue,
    updatedTransactions transactions: [SKPaymentTransaction]
  ) {
		for transaction in transactions {
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
				transactionDidSucceed(paywallViewController: paywallViewController, for: product)
			case .failed:
				if let error = transaction.error as? SKError {
					var userCancelled = error.code == .paymentCancelled
					if #available(iOS 12.2, *) {
						userCancelled = error.code == .overlayCancelled || error.code == .paymentCancelled
					}

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
				break
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
