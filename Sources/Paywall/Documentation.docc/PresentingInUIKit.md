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
