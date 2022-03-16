# SwiftUI Example App

This app demonstrates how to use Superwall's *Paywall* SDK in SwiftUI. 

Sign up for a free Superwall account [here](https://superwall.com).


## Requirements

This sample uses:

- SwiftUI
- Xcode 13
- iOS 15
- Swift 5

## Features

| Feature                             | Sample Project Location                   |
| ----------------------------------- | ----------------------------------------- |
| 🕹 Configuring the *Paywall* SDK    | [Services/PaywallService.swift](SuperwallSwiftUIExample/SuperwallSwiftUIExample/Services/PaywallService.swift#L20) |
| 💰 Presenting a paywall             | [PresentPaywallView.swift](SuperwallSwiftUIExample/SuperwallSwiftUIExample/PresentPaywallView.swift#L35) |
| 👉 Triggering a paywall             | [TriggerPaywallView.swift](SuperwallSwiftUIExample/SuperwallSwiftUIExample/TriggerPaywallView.swift#L36) |
| 👥 Identifying the user             | [Services/PaywallService.swift](SuperwallSwiftUIExample/SuperwallSwiftUIExample/Services/PaywallService.swift#L31) |

## Getting Started

Clone or download the *Paywall* SDK from the [project home page](https://github.com/superwall-me/paywall-ios). Then, open **SuperwallSwiftUIExample.xcodeproj** in Xcode and take a look at the code inside the **SuperwallSwiftUIExample** folder.

Inside the **Services** folder, you'll see some helper classes. **PaywallService.swift** handles the setup and delegate methods of the *Paywall* SDK, and **StoreKitService.swift** handles the purchasing of in-app subscriptions.

**Products.storekit** is a StoreKit configuration file that is used to mimic the setup of real products on App Store Connect. This is for testing purposes so you can make test purchases within the sample app without having to set up App Store Connect. In a production app, you will of course need real products in App Store Connect but you can also use a StoreKit configuration file for testing purposes.

You'll see a few different SwiftUI files that handle the layout of the app and presenting of Paywalls.

Build and run the app and you'll see the welcome screen:

<img src="https://i.imgur.com/jKkBBNW.png" align="center" alt="The welcome screen" width="220px" />

## Configuring the SDK

As soon as you run the app, the *Paywall* SDK is configured with an `apiKey` and the `delegate` is set. We have provided a sample API key to get you up and running but when you integrate the *Paywall* SDK into your own app, you'll need to use your own. To get an API key, [sign up for a free account on Superwall](https://superwall.com).

## Identifying a user

On the welcome screen, enter your name in the **text field** and tap **Continue**. This saves to the user attributes using   [Paywall.setUserAttributes(_:)](SuperwallSwiftUIExample/SuperwallSwiftUIExample/Services/PaywallService.swift#L31). You don't need to set user attributes, but it can be useful if you want to recall information about the user on your paywall.

You'll see an overview screen:

<img src="https://i.imgur.com/4maP9Fh.png" align="center" alt="The overview screen" width="220px" />

## Showing a Paywall

Paywalls are created and enabled in the [Superwall Dashboard](https://superwall.com/dashboard) and are shown to users who don't have an active subscription. To show a paywall, you have two options: **presenting** or **triggering**.

### Presenting a Paywall 

A paywall is presented by using the `presentPaywall(isPresented:onPresent:onDismiss:onFail)` view modifier in [PresentPaywallView.swift](SuperwallSwiftUIExample/SuperwallSwiftUIExample/PresentPaywallView.swift#L36). 

The paywall assigned to the user is determined by the settings in the Superwall Dashboard. Once a user is assigned a paywall, they will continue to see the same paywall, even when the paywall is turned off, unless you reassign them to a new one.

Tap **Presenting a Paywall**. You'll see some explanatory text and a button that presents a paywall to the user:

<img src="https://i.imgur.com/pRBHy0R.png" align="center" alt="Presenting a paywall" width="220px" />

Then, tap **Present Paywall** to see your paywall. Have a tap around, you'll see delegate methods getting called

### Triggering a Paywall

When you 

## Support

For an in-depth explanation of how to use the *Paywall* SDK, [check out our documentation](https://docs.superwall.com).
