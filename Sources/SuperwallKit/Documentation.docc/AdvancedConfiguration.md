# Advanced Configuration

Use options and custom subscription-related logic for more control over the SDK.

## Overview

By default, Superwall handles all subscription-related logic. However, if you're using RevenueCat, or you just want more control, you can return a ``SuperwallKit/SubscriptionController`` in
 the delegate when configuring the SDK via
 ``Superwall/configure(apiKey:delegate:options:completion:)-7fafw``. In addition, you can customise aspects of the SDK by passing in a ``SuperwallOptions`` object on configure.

## Creating a Subscription Controller

A subscription controller handles purchasing and restoring via protocol methods that you implement. You return your subscription controller via a `subscriptionController()` method in the ``SuperwallDelegate``, which you pass in when configuring the SDK:

```swift
import SuperwallKit

final class SuperwallService {
  private static let apiKey = "MYAPIKEY" // Replace this with your API Key
  static let shared = SuperwallService()

  static func initialize() {
    Superwall.configure(
      apiKey: apiKey,
      delegate: shared
    )
  }
}

// MARK: - Superwall Delegate
extension SuperwallService: SuperwallDelegate {
  func subscriptionController() -> SubscriptionController {
    return self
  }
}

// MARK: - SubscriptionController
extension SuperwallService: SubscriptionController {
  // 1
  func purchase(product: SKProduct) async -> PurchaseResult {
    // TODO: Purchase the product here and return its result.
    return .cancelled
  }

  // 2
  func restorePurchases() async -> Bool {
    // TODO: Restore purchases and call completion block with boolean indicating
    // the success status of restoration.
    return false
  }
}
```

All methods of the ``SubscriptionController`` are mandatory and receive callbacks from the SDK in response to certain events that happen on the paywall. It is up to you to fill these methods with the appropriate code. Here's what each method is responsible for:

1. Purchasing a given product. In here, enter your code that you use to purchase a product. If you're using RevenueCat, you'll need to turn off StoreKit2 when initialising the SDK. Then, handle the result by returning a `PurchaseResult`. This is an enum that contains the following cases, all of which must be handled. Check out our example apps for further information about handling these cases:
    - `.cancelled`: The purchase was cancelled.
    - `.purchased`: The product was purchased.
    - `.pending`: The purchase is pending and requires action from the developer.
    - `.failed(Error)`: The purchase failed for a reason other than the user cancelling or the payment pending.

2. Restoring purchases. Make sure to call the completion block after you attempt to restore purchases to let the SDK know whether the restoration was successful or not.

## Setting User Subscription Status

In addition to creating a `SubscriptionController`, you need to tell the SDK the user's subscription status every time it changes. To do this, you need to set ``Superwall/subscriptionStatus``:

```
  Superwall.shared.subscriptionStatus = .active
```

or

```
  Superwall.shared.subscriptionStatus = .inactive
```

This is a ``SubscriptionStatus`` enum that has three possible cases:

1. **`.unknown`**: This is the default value. In this state, paywalls will not show until the state changes to `.active` or `.inactive`.

2. **`.active`**: Indicates that the user has an active subscription. Paywalls will not show in this state (unless you specifically set the paywall to ignore subscription status).

3. **`.inactive`**: Indicates that the user doesn't have an active subscription.

## Passing in Superwall Options

When configuring the SDK you can pass in options that configure Superwall, the paywall presentation, and its appearance. Take a look at ``SuperwallOptions`` for all possible values.
