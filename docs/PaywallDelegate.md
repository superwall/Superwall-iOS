# PaywallDelegate

Methods for managing important Paywall lifecycle events. For example, telling the developer when to initiate checkout on a specific `SKProduct` and when to try to restore a transaction. Also includes hooks for you to log important analytics events to your product analytics tool.

``` swift
@objc public protocol PaywallDelegate: AnyObject 
```

## Inheritance

`AnyObject`

## Requirements

### userDidInitiateCheckout(for:​)

Called when the user initiates checkout for a product. Add your purchase logic here by either calling `Purchases.shared.purchaseProduct()` (if you use RevenueCat:​ https:​//sdk.revenuecat.com/ios/Classes/RCPurchases.html\#/c:​objc(cs)RCPurchases(im)purchaseProduct:​withCompletionBlock:​) or by using Apple's StoreKit APIs

``` swift
func userDidInitiateCheckout(for product: SKProduct)
```

#### Parameters

  - product: The `SKProduct` the user would like to purchase

### shouldTryToRestore()

Called when the user initiates a restore. Add your restore logic here.

``` swift
func shouldTryToRestore()
```

## Optional Requirements

### didReceiveCustomEvent(withName:​)

Called when the user taps a button with a custom `data-pw-custom` tag in your HTML paywall. See paywall.js for further documentation

``` swift
@objc optional func didReceiveCustomEvent(withName name: String)
```

#### Parameters

  - withName: The value of the `data-pw-custom` tag in your HTML element that the user selected.

### willDismissPaywall()

Called right before the paywall is dismissed.

``` swift
@objc optional func willDismissPaywall()
```

### willPresentPaywall()

Called right before the paywall is presented.

``` swift
@objc optional func willPresentPaywall()
```

### didDismissPaywall()

Called right after the paywall is dismissed.

``` swift
@objc optional func didDismissPaywall()
```

### didPresentPaywall()

Called right after the paywall is presented.

``` swift
@objc optional func didPresentPaywall()
```

### willOpenURL(url:​)

Called when the user opens a URL by selecting an element with the `data-pw-open-url` tag in your HTML paywall.

``` swift
@objc optional func willOpenURL(url: URL)
```

### willOpenDeepLink(url:​)

Called when the user taps a deep link in your HTML paywall.

``` swift
@objc optional func willOpenDeepLink(url: URL)
```

### shouldTrack(event:​params:​)

Called when you should track a standard internal analytics event to your own system.

``` swift
@objc optional func shouldTrack(event: String, params: [String: Any])
```

Possible Values:

``` swift
// App Lifecycle Events
Paywall.delegate.shouldTrack(event: "app_install", params: nil)
Paywall.delegate.shouldTrack(event: "app_open", params: nil)
Paywall.delegate.shouldTrack(event: "app_close", params: nil)

// Paywall Events
Paywall.delegate.shouldTrack(event: "paywall_open", params: ['paywall_id': 'someid'])
Paywall.delegate.shouldTrack(event: "paywall_close", params: ['paywall_id': 'someid'])

// Transaction Events
Paywall.delegate.shouldTrack(event: "transaction_start", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
Paywall.delegate.shouldTrack(event: "transaction_fail", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
Paywall.delegate.shouldTrack(event: "transaction_abandon", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
Paywall.delegate.shouldTrack(event: "transaction_complete", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
Paywall.delegate.shouldTrack(event: "transaction_restore", params: ['paywall_id': 'someid', 'product_id': 'someskid'])

// Purchase Events
Paywall.delegate.shouldTrack(event: "subscription_start", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
Paywall.delegate.shouldTrack(event: "freeTrial_start", params: ['paywall_id': 'someid', 'product_id': 'someskid'])
Paywall.delegate.shouldTrack(event: "nonRecurringProduct_purchase", params: ['paywall_id': 'someid', 'product_id': 'someskid'])

// Superwall API Request Events
Paywall.delegate.shouldTrack(event: "paywallResponseLoad_start", params: ['paywall_id': 'someid'])
Paywall.delegate.shouldTrack(event: "paywallResponseLoad_fail", params: ['paywall_id': 'someid'])
Paywall.delegate.shouldTrack(event: "paywallResponseLoad_complete", params: ['paywall_id': 'someid'])

// Webview Reqeuest Events
Paywall.delegate.shouldTrack(event: "paywallWebviewLoad_start", params: ['paywall_id': 'someid'])
Paywall.delegate.shouldTrack(event: "paywallWebviewLoad_fail", params: ['paywall_id': 'someid'])
Paywall.delegate.shouldTrack(event: "paywallWebviewLoad_complete", params: ['paywall_id': 'someid'])
```
