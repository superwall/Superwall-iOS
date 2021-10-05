//
//  File.swift
//  
//
//  Created by Jake Mor on 10/5/21.
//

import Foundation
import StoreKit

/// Methods for managing important Paywall lifecycle events. For example, telling the developer when to initiate checkout on a specific `SKProduct` and when to try to restore a transaction. Also includes hooks for you to log important analytics events to your product analytics tool.
@objc public protocol PaywallDelegate: AnyObject {
	
	/// Called when the user initiates checkout for a product. Add your purchase logic here by either calling `Purchases.shared.purchaseProduct()` (if you use RevenueCat: https://sdk.revenuecat.com/ios/Classes/RCPurchases.html#/c:objc(cs)RCPurchases(im)purchaseProduct:withCompletionBlock:) or by using Apple's StoreKit APIs
	/// - Parameter product: The `SKProduct` the user would like to purchase
	@objc func userDidInitiateCheckout(for product: SKProduct)
	
	/// Called when the user initiates a restore. Add your restore logic here.
	@objc func shouldTryToRestore()
	
	/// Called before ever showing a paywall. Return `false` if the user has active entitlements and `true` if the user does not.
	@objc func shouldPresentPaywall() -> Bool
	
	/// Called when the user taps a button with a custom `data-pw-custom` tag in your HTML paywall. See paywall.js for further documentation
	///  - Parameter withName: The value of the `data-pw-custom` tag in your HTML element that the user selected.
	@objc optional func didReceiveCustomEvent(withName name: String)
	
	/// Called right before the paywall is dismissed.
	@objc optional func willDismissPaywall()
	
	/// Called right before the paywall is presented.
	@objc optional func willPresentPaywall()

	/// Called right after the paywall is dismissed.
	@objc optional func didDismissPaywall()
	
	/// Called right after the paywall is presented.
	@objc optional func didPresentPaywall()
	
	/// Called when the user opens a URL by selecting an element with the `data-pw-open-url` tag in your HTML paywall.
	@objc optional func willOpenURL(url: URL)
	
	/// Called when the user taps a deep link in your HTML paywall.
	@objc optional func willOpenDeepLink(url: URL)
	
	/// Called when you should track a standard internal analytics event to your own system. If you want the event's name as an enum, do this:`let e = Paywall.EventName(rawValue: name)`
	///
	
	/// Possible Values:
	///  ```swift
	/// // App Lifecycle Events
	/// Paywall.delegate.shouldTrack(event: "app_install", params: nil)
	/// Paywall.delegate.shouldTrack(event: "app_open", params: nil)
	/// Paywall.delegate.shouldTrack(event: "app_close", params: nil)
	///
	/// // Paywall Events
	/// Paywall.delegate.shouldTrack(event: "paywall_open", params: ['paywall_id': 'someid'])
	/// Paywall.delegate.shouldTrack(event: "paywall_close", params: ['paywall_id': 'someid'])
	///
	/// // Transaction Events
	/// Paywall.delegate.shouldTrack(event: "transaction_start", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	/// Paywall.delegate.shouldTrack(event: "transaction_fail", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	/// Paywall.delegate.shouldTrack(event: "transaction_abandon", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	/// Paywall.delegate.shouldTrack(event: "transaction_complete", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	/// Paywall.delegate.shouldTrack(event: "transaction_restore", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	///
	/// // Purchase Events
	/// Paywall.delegate.shouldTrack(event: "subscription_start", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	/// Paywall.delegate.shouldTrack(event: "freeTrial_start", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	/// Paywall.delegate.shouldTrack(event: "nonRecurringProduct_purchase", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
	///
	/// // Superwall API Request Events
	/// Paywall.delegate.shouldTrack(event: "paywallResponseLoad_start", params: ['paywall_id': 'someid'])
	/// Paywall.delegate.shouldTrack(event: "paywallResponseLoad_fail", params: ['paywall_id': 'someid'])
	/// Paywall.delegate.shouldTrack(event: "paywallResponseLoad_complete", params: ['paywall_id': 'someid'])
	///
	/// // Webview Reqeuest Events
	/// Paywall.delegate.shouldTrack(event: "paywallWebviewLoad_start", params: ['paywall_id': 'someid'])
	/// Paywall.delegate.shouldTrack(event: "paywallWebviewLoad_fail", params: ['paywall_id': 'someid'])
	/// Paywall.delegate.shouldTrack(event: "paywallWebviewLoad_complete", params: ['paywall_id': 'someid'])
	/// ```
	
	
	@objc optional func shouldTrack(event: String, params: [String: Any])

}
