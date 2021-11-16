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
	
	private func _transactionDidBegin(for product: SKProduct) {
		
		if let i = paywallViewController?.paywallInfo {
			Paywall.track(.transactionStart(paywallInfo: i, product: product))
		}
		
		paywallViewController?.loadingState = .loadingPurchase
		
		OnMain { [weak self] in
			self?.paywallViewController?.showRefreshButtonAfterTimeout(show: false)
		}
		
		
	}

	
	private func _transactionDidSucceed(for product: SKProduct) {
		
		if let i = paywallViewController?.paywallInfo {
			Paywall.track(.transactionComplete(paywallInfo: i, product: product))
			if let ft = paywallViewController?._paywallResponse?.isFreeTrialAvailable {
				if ft {
					Paywall.track(.freeTrialStart(paywallInfo: i, product: product))
				} else {
					Paywall.track(.subscriptionStart(paywallInfo: i, product: product))
				}
			}
		}
		

		
		_dismiss(userDidPurchase: true, productId: product.productIdentifier)
	}
	

	
	private func _transactionErrorDidOccur(error: SKError?, for product: SKProduct) {
		// prevent a recursive loop
		OnMain { [weak self] in
			
			
			guard let self = self else { return }
			
			self.paywallViewController?.loadingState = .ready
			
			if !self.didTryToAutoRestore {
				Paywall.shared.tryToRestore()
				self.didTryToAutoRestore = true
			} else {
				self.paywallViewController?.loadingState = .ready
				
				if let i = self.paywallViewController?.paywallInfo {
					Paywall.track(.transactionFail(paywallInfo: i, product: product, message: error?.localizedDescription ?? ""))
				}
				
				self.paywallViewController?.presentAlert(title: "Please try again", message: error?.localizedDescription ?? "", actionTitle: "Restore Purchase", action: {
					Paywall.shared.tryToRestore()
				})
			}
		}
	}
	
	internal func tryToRestore(userInitiated: Bool = false) {
		OnMain {
			
			Logger.superwallDebug(string: "attempting restore ...")
			
			if let d = Paywall.delegate {
				
				if userInitiated {
					self.paywallViewController?.loadingState = .loadingPurchase
				}
				
				d.restorePurchases { [weak self] success in
					OnMain { [weak self] in
						if userInitiated {
							self?.paywallViewController?.loadingState = .ready
						}
						if success {
							Logger.superwallDebug(string: "transaction restored")
							Logger.superwallDebug(string: "[Transaction Observer] restored")
							self?._transactionWasRestored()
						} else {
							Logger.superwallDebug(string: "transaction failed to restore")
							if userInitiated {
								self?.paywallViewController?.presentAlert(title: Paywall.restoreFailedTitleString, message: Paywall.restoreFailedMessageString, closeActionTitle: Paywall.restoreFailedCloseButtonString)
							}
						}
					}
				}
			}
			
		}
	}
	
	private func _transactionWasAbandoned(for product: SKProduct) {
		if let i = paywallViewController?.paywallInfo {
			Paywall.track(.transactionAbandon(paywallInfo: i, product: product))
		}
		
		paywallViewController?.loadingState = .ready
	}
	
	private func _transactionWasRestored() {
		if let i = paywallViewController?.paywallInfo {
			Paywall.track(.transactionRestore(paywallInfo: i, product: nil))
		}
		_dismiss(userDidPurchase: true)
	}
	
	// if a parent needs to approve the purchase
	private func _transactionWasDeferred() {
		paywallViewController?.presentAlert(title: "Waiting for Approval", message: "Thank you! This purchase is pending approval from your parent. Please try again once it is approved.")
	   
		
		if let i = paywallViewController?.paywallInfo {
			Paywall.track(.transactionFail(paywallInfo: i, product: nil, message: "Needs parental approval"))
		}
	}
	
}


extension Paywall: SKPaymentTransactionObserver {
	
	public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
		Logger.superwallDebug(string: "[Transaction Observer] paymentQueueRestoreCompletedTransactionsFinished")
	}
	
	public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
		Logger.superwallDebug(string: "[Transaction Observer] restoreCompletedTransactionsFailedWithError", error: error)
	}
	
	public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		for transaction in transactions {
			
			guard paywallWasPresentedThisSession else { return }
			
			guard let product = StoreKitManager.shared.productsById[transaction.payment.productIdentifier] else { return }
			switch transaction.transactionState {
			case .purchased:
				Logger.superwallDebug(string: "[Transaction Observer] transactionDidSucceed for: \(product.productIdentifier)")
				self._transactionDidSucceed(for: product)
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
						Logger.superwallDebug(string: "[Transaction Observer] transactionWasAbandoned for: \(product.productIdentifier)", error: e)
						self._transactionWasAbandoned(for: product)
						return
					} else {
						Logger.superwallDebug(string: "[Transaction Observer] transactionErrorDidOccur for: \(product.productIdentifier)", error: e)
						self._transactionErrorDidOccur(error: e, for: product)
						return
					}
				} else {
					self._transactionErrorDidOccur(error: nil, for: product)
					Logger.superwallDebug(string: "[Transaction Observer] transactionErrorDidOccur for: \(product.productIdentifier)", error: transaction.error)
					OnMain { [weak self] in
						self?.paywallViewController?.presentAlert(title: "Something went wrong", message: transaction.error?.localizedDescription ?? "", actionTitle: nil, action: nil)
					}
				}
			  
			break
			case .restored:
				
				break
			case .deferred:
				Logger.superwallDebug(string: "[Transaction Observer] deferred")
				_transactionWasDeferred()
			case .purchasing:
				Logger.superwallDebug(string: "[Transaction Observer] purchasing")
				_transactionDidBegin(for: product)
			default:
				paywallViewController?.loadingState = .ready
			}
		}
	}
}


