# Getting Started with Paywall

Configuring the SDK and its delegate.

## Overview

To get up and running, you need to get your **API Key** from the Superwall Dashboard. You then configure the SDK using ``Paywall/Paywall/configure(apiKey:userId:delegate:)``. You pass this function a class that conforms to ``Paywall/PaywallDelegate``, which handles actions taken on the paywall. You can then present your first paywall.

### Getting your API Key

As soon as the app is launched, you need to configure the SDK with your **Public API Key**. You can retrieve this from the Superwall settings page.
If you haven't already, [sign up for a free Superwall account](https://superwall.com/sign-up). Then, when you're through to the **Dashboard**, click the **Settings icon** in the top right corner, and select **Keys**:

![Retrieving your API key from the Superwall Dashboard](apiKey.png)

On that page, you will see your **Public API Key**. Copy this for the next step.

### Configuring the SDK

To configure the SDK, you call ``Paywall/Paywall/configure(apiKey:userId:delegate:)`` from ``application(_:didFinishLaunchingWithOptions:)``. We recommended creating a service class **PaywallService.swift** that handles your SDK configuration and delegate callbacks:

```swift
import Paywall

final class PaywallService {
  static let apiKey = "MYAPIKEY" // Replace this with your API Key
  static var shared = PaywallService()

  static func initPaywall() {
    Paywall.configure(
      apiKey: apiKey,
      userId: "aUniqueUserId"
      delegate: shared
    )
  }
}
```

This configures a shared instance of ``Paywall/Paywall`` for use throughout your app and sets the delegate to the PaywallService shared instance. Make sure to replace the `apiKey` with your Public API key that you just retrieved.

If you have a unique ID of your user, you can enter it in `userId`. Otherwise we will generate a random id that will persist internally until you call ``Paywall/Paywall/reset()`` or the user deletes/reinstalls your app.

Later on, you can identify a user using ``Paywall/Paywall/identify(userId:)``. Superwall will then alias the userId you provide to the random userId we generated on your behalf.

### Setting the delegate

To conform to ``PaywallDelegate``, extend PaywallService:

```swift
// MARK: - Paywall Delegate
extension PaywallService: PaywallDelegate {
  // 1
  func purchase(product: SKProduct) {
    // TODO: Purchase the product here
  }

  // 2
  func restorePurchases(completion: @escaping (Bool) -> Void) {
    // TODO: Restore purchases and call completion block with boolean indicating
    // the success status of restoration
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

### Configuring From the App Delegate

Next, call `initPaywall()` from `application(_:didFinishLaunchingWithOptions:)` in your App Delegate:

```swift
import Paywall

final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication, 
    didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?
  ) -> Bool {
    PaywallService.initPaywall()
  )
}
```

You're now ready to present or trigger your paywall.
