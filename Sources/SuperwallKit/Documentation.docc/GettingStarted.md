# Getting Started with Superwall

Configuring the SDK and its delegate.

## Overview

To get up and running, you need to get your **API Key** from the Superwall Dashboard. You then configure the SDK using ``SuperwallKit/Superwall/configure(apiKey:delegate:options:)-7doe5``. You pass this function a class that conforms to ``SuperwallDelegate``, which handles actions taken on the paywall. You can then present your paywall.

## Getting your API Key

As soon as the app is launched, you need to configure the SDK with your **Public API Key**. You can retrieve this from the Superwall settings page.
If you haven't already, [sign up for a free Superwall account](https://superwall.com/sign-up). Then, when you're through to the **Dashboard**, click the **Settings icon** in the top right corner, and select **Keys**:

![Retrieving your API key from the Superwall Dashboard](apiKey.png)

On that page, you will see your **Public API Key**. Copy this for the next step.

### Configuring the SDK

To configure the SDK, you call ``SuperwallKit/Superwall/configure(apiKey:delegate:options:)-7doe5`` from  `application(_:didFinishLaunchingWithOptions:)`. We recommended creating a service class **SuperwallService.swift** that handles your SDK configuration and delegate callbacks:

```swift
import SuperwallKit

final class SuperwallService {
  static let apiKey = "MYAPIKEY" // Replace this with your API Key
  static let shared = SuperwallService()

  static func initSuperwall() {
    Superwall.configure(
      apiKey: apiKey,
      delegate: shared
    )
  }
}
```

This configures a shared instance of ``SuperwallKit/Superwall`` for use throughout your app and sets the delegate to the `SuperwallService` shared instance. Make sure to replace the `apiKey` with your Public API key that you just retrieved.


## Identity Management

We generate a random user ID that persists internally until the user deletes/reinstalls your app.

If you use your own user management system, you can call ``SuperwallKit/Superwall/createAccount(userId:)`` when a user first creates an account, and ``SuperwallKit/Superwall/logIn(userId:)`` if you're logging in an existing user. This will alias your `userId` with the anonymous Superwall ID enabling us to load the user's assigned paywalls.

Calling ``SuperwallKit/Superwall/logOut()`` or ``SuperwallKit/Superwall/reset()`` will reset the on-device `userId` to a random ID and clear the paywall assignments.

## Setting the delegate

To conform to ``SuperwallDelegate``, extend SuperwallService:

```swift
// MARK: - Paywall Delegate
extension SuperwallService: SuperwallDelegate {
  // 1
  func purchase(product: SKProduct) {
    // TODO: Purchase the product here
  }

  // 2
  func restorePurchases(completion: @escaping (Bool) -> Void) {
    // TODO: Restore purchases and call completion block with boolean indicating the success status of restoration
    completion(false)
  }

  // 3
  func isUserSubscribed() -> Bool {
    // TODO: Replace with boolean indicating the user's subscription status
    return false
  }
}
```

These delegate methods are mandatory and receive callbacks from the SDK in response to certain events that happen on the paywall. It is up to you to fill these methods with the appropriate code. Here's what each method is responsible for:

1. Purchasing a given product. In here, enter your code that you use to purchase a product.
2. Restoring purchases. Make sure to call the completion block after you attempt to restore purchases to let the SDK know whether the restoration was successful or not.
3. Telling the SDK whether the user has an active subscription. Replace this with a boolean indicating the user's subscription status.


## Configuring From the App Delegate

Next, call `initSuperwall()` from `application(_:didFinishLaunchingWithOptions:)` in your App Delegate:

```swift
import SuperwallKit

final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication, 
    didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?
  ) -> Bool {
    SuperwallService.initSuperwall()
  )
}
```

You're now ready to track an event to present your first paywall. See <doc:TrackingEvents> for next steps.

## Topics

### The Delegate
- ``SuperwallDelegate``
- <doc:CustomPaywallButtons>
- <doc:ThirdPartyAnalytics>

### Customising Superwall
- ``SuperwallOptions``
