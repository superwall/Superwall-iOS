//
//  File.swift
//  
//
//  Created by Jake Mor on 11/16/21.
//

import Foundation
import StoreKit


extension Paywall {
	
	// purchase callbacks
	
	private func _transactionDidBegin(paywallViewController: SWPaywallViewController, for product: SKProduct) {
		
		if let i = paywallViewController.paywallInfo {
			Paywall.track(.transactionStart(paywallInfo: i, product: product))
		}
		
		paywallViewController.loadingState = .loadingPurchase
		
		OnMain { 
			paywallViewController.showRefreshButtonAfterTimeout(show: false)
		}
		
		
	}

	
	private func _transactionDidSucceed(paywallViewController: SWPaywallViewController, for product: SKProduct) {
		
		if let i = paywallViewController.paywallInfo {
			Paywall.track(.transactionComplete(paywallInfo: i, product: product))
			if let ft = paywallViewController._paywallResponse?.isFreeTrialAvailable {
				if ft {
					Paywall.track(.freeTrialStart(paywallInfo: i, product: product))
				} else {
					Paywall.track(.subscriptionStart(paywallInfo: i, product: product))
				}
			}
		}
		

		
		_dismiss(paywallViewController: paywallViewController, userDidPurchase: true, productId: product.productIdentifier)
	}
	

	
	private func _transactionErrorDidOccur(paywallViewController: SWPaywallViewController, error: SKError?, for product: SKProduct) {
		// prevent a recursive loop
		OnMain { [weak self] in
			
			
			guard let self = self else { return }
			
			paywallViewController.loadingState = .ready
			
			if !self.didTryToAutoRestore {
				Paywall.shared.tryToRestore(paywallViewController: paywallViewController)
				self.didTryToAutoRestore = true
			} else {
				paywallViewController.loadingState = .ready
				
				if let i = paywallViewController.paywallInfo {
					Paywall.track(.transactionFail(paywallInfo: i, product: product, message: error?.localizedDescription ?? ""))
				}
				
				self.paywallViewController?.presentAlert(title: "Please try again", message: error?.localizedDescription ?? "", actionTitle: "Restore Purchase", action: {
					Paywall.shared.tryToRestore(paywallViewController: paywallViewController)
				})
			}
		}
	}
	
	internal func tryToRestore(paywallViewController: SWPaywallViewController, userInitiated: Bool = false) {
		OnMain {
			
			
			Logger.debug(logLevel: .debug, scope: .paywallTransactions, message: "Attempting Restore", info: nil, error: nil)
			
			if let d = Paywall.delegate {
				
				if userInitiated {
					paywallViewController.loadingState = .loadingPurchase
				}
				
				d.restorePurchases { [weak self] success in
					OnMain { [weak self] in
						if userInitiated {
							paywallViewController.loadingState = .ready
						}
						if success {
							Logger.debug(logLevel: .debug, scope: .paywallTransactions, message: "Transaction Restored", info: nil, error: nil)
							self?._transactionWasRestored(paywallViewController: paywallViewController)
						} else {
							Logger.debug(logLevel: .debug, scope: .paywallTransactions, message: "Transaction Failed to Restore", info: nil, error: nil)
							if userInitiated {
								paywallViewController.presentAlert(title: Paywall.restoreFailedTitleString, message: Paywall.restoreFailedMessageString, closeActionTitle: Paywall.restoreFailedCloseButtonString)
							}
						}
					}
				}
			}
			
		}
	}
	
	private func _transactionWasAbandoned(paywallViewController: SWPaywallViewController, for product: SKProduct) {
		if let i = paywallViewController.paywallInfo {
			Paywall.track(.transactionAbandon(paywallInfo: i, product: product))
		}
		
		paywallViewController.loadingState = .ready
	}
	
	private func _transactionWasRestored(paywallViewController: SWPaywallViewController) {
		if let i = paywallViewController.paywallInfo {
			Paywall.track(.transactionRestore(paywallInfo: i, product: nil))
		}
		_dismiss(paywallViewController: paywallViewController, userDidPurchase: true)
	}
	
	// if a parent needs to approve the purchase
	private func _transactionWasDeferred(paywallViewController: SWPaywallViewController) {
		paywallViewController.presentAlert(title: "Waiting for Approval", message: "Thank you! This purchase is pending approval from your parent. Please try again once it is approved.")
	   
		if let i = paywallViewController.paywallInfo {
			Paywall.track(.transactionFail(paywallInfo: i, product: nil, message: "Needs parental approval"))
		}
	}
	
}


extension Paywall: SKPaymentTransactionObserver {
	
	public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
		Logger.debug(logLevel: .debug, scope: .paywallTransactions, message: "Restore Completed Transactions Finished", info: nil, error: nil)
	}
	
	public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
		Logger.debug(logLevel: .debug, scope: .paywallTransactions, message: "Restore Completed Transactions Failed With Error", info: nil, error: error)
	}
	
	public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		for transaction in transactions {
			
			guard paywallWasPresentedThisSession else { return }
			guard let paywallViewController = paywallViewController else { return }
			
			guard let product = StoreKitManager.shared.productsById[transaction.payment.productIdentifier] else { return }
			switch transaction.transactionState {
			case .purchased:
				Logger.debug(logLevel: .debug, scope: .paywallTransactions, message: "Transaction Succeeded", info: ["product_id": product.productIdentifier, "paywall_vc": paywallViewController], error: nil)
				self._transactionDidSucceed(paywallViewController: paywallViewController, for: product)
			break
			case .failed:
				if let e = transaction.error as? SKError {
					var userCancelled = e.code == .paymentCancelled
					if #available(iOS 12.2, *) {
						userCancelled = e.code == .overlayCancelled || e.code == .paymentCancelled
					}

					if #available(iOS 14.0, *) {
						userCancelled = e.code == .overlayCancelled || e.code == .paymentCancelled || e.code == .overlayTimeout
					}

					if userCancelled {
						Logger.debug(logLevel: .debug, scope: .paywallTransactions, message: "Transaction Abandoned", info: ["product_id": product.productIdentifier, "paywall_vc": paywallViewController], error: nil)
						self._transactionWasAbandoned(paywallViewController: paywallViewController, for: product)
						return
					} else {
						Logger.debug(logLevel: .debug, scope: .paywallTransactions, message: "Transaction Error", info: ["product_id": product.productIdentifier, "paywall_vc": paywallViewController], error: e)
						self._transactionErrorDidOccur(paywallViewController: paywallViewController, error: e, for: product)
						return
					}
				} else {
					Logger.debug(logLevel: .debug, scope: .paywallTransactions, message: "Transaction Error", info: ["product_id": product.productIdentifier, "paywall_vc": paywallViewController], error: transaction.error)
					self._transactionErrorDidOccur(paywallViewController: paywallViewController, error: nil, for: product)
					OnMain { 
						paywallViewController.presentAlert(title: "Something went wrong", message: transaction.error?.localizedDescription ?? "", actionTitle: nil, action: nil)
					}
				}
			  
			break
			case .restored:
				
				break
			case .deferred:
				Logger.debug(logLevel: .debug, scope: .paywallTransactions, message: "Transaction Deferred", info: ["paywall_vc": paywallViewController], error: nil)
				_transactionWasDeferred(paywallViewController: paywallViewController)
			case .purchasing:
				Logger.debug(logLevel: .debug, scope: .paywallTransactions, message: "Transaction Purchasing", info: ["paywall_vc": paywallViewController], error: nil)
				_transactionDidBegin(paywallViewController: paywallViewController, for: product)
			default:
				paywallViewController.loadingState = .ready
			}
		}
	}
}


