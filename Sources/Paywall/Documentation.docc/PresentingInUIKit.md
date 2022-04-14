# Presenting a Paywall with UIKit

Call a UIKit function to present a paywall and receive callbacks associated with the paywall presentation state.

## Overview

To present a paywall in UIKit, you call ``Paywall/Paywall/present(onPresent:onDismiss:onFail:)``. It shows the paywall when the user doesn't have an active subscription. You can then receive callbacks associated with the paywall presentation state.

> Important: The paywall assigned to the user is determined by your settings in the [Superwall Dashboard](https://superwall.com/dashboard). Presented paywalls are **sticky**. This means that once a user is assigned a paywall, they will continue to see the same paywall, even when the paywall is turned off, unless you reassign them to a new one.

### Presenting the Paywall

```swift
Paywall.present(
  onPresent: { info in
    // access info about the presented paywall
  }
  onFail: { error in 
    // Log the error
    // Fallback to presenting your old paywall
  },
  onDismiss: { didPurchase, productId, paywallInfo in
    // Add custom logic after paywall is dismissed
  }
)
```

The `onPresent`, `onFail`, and `onDismiss` callbacks are optional. They provide the following functionality:

Parameter  | Type | Functionality
--- | --- | ---
`onPresent` | `(PaywallInfo) -> Void` | A closure that’s called after the paywall is presented. Accepts an optional ``Paywall/PaywallInfo`` object containing information about the paywall. Defaults to `nil`.
`onDismiss` | `(didPurchase: Bool, productId: String?, info: PaywallInfo) → Void` | The closure to execute after the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Called when the paywall is dismissed (either by the user or because a purchase occurred). If `didPurchase` is `true`, `productId` contains the id of the purchased product. Defaults to `nil`.
`onFail` | `(NSError?) -> Void` | Called if an error occurs while showing your paywall, either because something is misconfigured, all paywalls are off, or if an unexpected response is received from our server. You should typically fallback to your previous paywall if this happens. Defaults to nil.

Occasionally you may want to specify a paywall or view controller to present the paywall on. These two parameters are also included in ``Paywall/Paywall/present(identifier:on:ignoreSubscriptionStatus:onPresent:onDismiss:onFail:)`` for these special occasions:

Parameter  | Type | Functionality
--- | --- | ---
`identifier` | `String` | The identifier of a specific paywall you would like to show. We do NOT recommend using this – best to enable / disable paywalls from the dashboard. Defaults to presenting whatever paywall is enabled in the dashboard, in a round robin fashion.
`on` | `UIViewController` | The view controller to present the paywall on. Defaults to presenting on a new window on top of the current window.
