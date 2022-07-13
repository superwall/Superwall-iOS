# SwiftUI Example App

This app demonstrates how to use Superwall's *Paywall* SDK in SwiftUI. We've written a mini tutorial below to help you understand what's going on in the app.

Usually, to integrate the SDK into your app, you first need to have configured and enabled a paywall using the [Superwall Dashboard](https://superwall.com/dashboard). However, with this example app, we have already done that for you and provided a sample API key to get you up and running. When you integrate the SDK into your own app, you'll need to use your own API key for your own Superwall account. To do that, [sign up for a free account on Superwall](https://superwall.com/sign-up).

## Features

Feature | Sample Project Location
--- | ---
🕹 Configuring the *Paywall* SDK | [Services/PaywallService.swift](SuperwallSwiftUIExample/Services/PaywallService.swift#L20)
👉 Explicitly Triggering a paywall | [ExplicitlyTriggerPaywallView.swift](SuperwallSwiftUIExample/ExplicitlyTriggerPaywallView.swift#L36)
👉 Explicitly Triggering a paywall | [ImplicitlyTriggerPaywallView.swift](SuperwallSwiftUIExample/ImplicitlyTriggerPaywallView.swift#L36)
👥 Identifying the user | [Services/PaywallService.swift](SuperwallSwiftUIExample/Services/PaywallService.swift#L31)

## Requirements

This example app uses:

- SwiftUI
- Xcode 13
- iOS 15
- Swift 5

You'll need to have SwiftLint installed. If you use Homebrew to install packages on your computer you run the following in the command line:

`brew install swiftlint`

Otherwise, you can download it from [https://github.com/realm/SwiftLint](https://github.com/realm/SwiftLint).

## Getting Started

Clone or download the *Paywall* SDK from the [project home page](https://github.com/superwall-me/paywall-ios). Then, open **SuperwallSwiftUIExample.xcodeproj** in Xcode and take a look at the code inside the [SuperwallSwiftUIExample](SuperwallSwiftUIExample) folder.

Inside the [Services](SuperwallSwiftUIExample/Services) folder, you'll see some helper classes. [PaywallService.swift](SuperwallSwiftUIExample/Services/PaywallService.swift) handles the setup and delegate methods of the SDK, and [StoreKitService.swift](SuperwallSwiftUIExample/Services/StoreKitService.swift) handles the purchasing of in-app subscriptions.

[Products.storekit](SuperwallSwiftUIExample/Products.storekit) is a StoreKit configuration file that is used to mimic the setup of real products on App Store Connect. This is so you can make test purchases within the sample app without having to set up App Store Connect. In a production app, you will need real products configured in App Store Connect but you can also use a StoreKit configuration file for testing purposes if you wish.

You'll see a few different SwiftUI files that handle the layout of the app and presenting of Paywalls.

Build and run the app and you'll see the welcome screen:

<p align="center">
  <img src="https://i.imgur.com/jKkBBNW.png" alt="The welcome screen" width="220px" />
</p>

The *Paywall* SDK is [configured](SuperwallSwiftUIExample/Services/PaywallService.swift#L20) on app launch, setting an `apiKey` and `delegate`.

The SDK sends back events received from the paywall via the delegate methods in [PaywallService.swift](SuperwallSwiftUIExample/Services/PaywallService.swift). You use these methods to make and restore purchases, react to analytical events, as well as tell the SDK whether the user has an active subscription. 

## Identifying a user

On the welcome screen, enter your name in the **text field** and tap **Continue**. This saves to the Paywall user attributes using   [Paywall.setUserAttributes(_:)](SuperwallSwiftUIExample/Services/PaywallService.swift#L31). You don't need to set user attributes, but it can be useful if you want to present paywalls based on specific user attributes or recall information about the user on your paywall.

You'll see an overview screen:

<p align="center">
  <img src="https://i.imgur.com/P3dYPuZ.png" alt="The overview screen" width="220px" />
</p>

## Showing a Paywall

Paywalls are created and enabled in the [Superwall Dashboard](https://superwall.com/dashboard) and are shown to users who don't have an active subscription. To show a paywall, you have two options: **explicitly triggering**, or **implicitly triggering**.

### Triggering a Paywall Explicitly

Triggers enable you to retroactively decide where or when to show a paywall in your app.

A trigger is an analytics event you can wire up to specific rules in a Campaign on the [Superwall Dashboard](https://superwall.com/dashboard). The Paywall SDK listens for these analytics events and evaluates their rules to determine whether or not to show a paywall when the trigger is fired.

In this app, we have tied an active trigger on the dashboard to the event "MyEvent". 

Head back to the overview screen, and tap on **Explicitly Triggering a Paywall**. You'll see some explanatory text and a button that triggers the paywall:

<p align="center">
  <img src="https://user-images.githubusercontent.com/3296904/158836596-10d00960-50b8-4fd0-a36f-dd484a305d22.png" alt="Explicitly triggering a paywall" width="220px" />
</p>


Tap the **Trigger Paywall** button and you'll see the same paywall as before come up. If the trigger in the dashboard is disabled, this trigger would stop working.

### Triggering a Paywall Implicitly

If you don't need completion handlers for triggering a paywall, you can use `track(_:_:)`.

Head back to the overview screen, and tap on **Implicitly Triggering a Paywall**. You'll see some explanatory text, and two buttons that increment and reset a counter:

<p align="center">
  <img src="https://user-images.githubusercontent.com/3296904/158837258-ad374697-ad0b-410d-90fc-638a8514d83f.png" alt="Implicitly triggering a paywall" width="220px" />
</p>

Tap on increment 3 times. When the counter reaches 3, it will track an event, which will implicitly trigger a paywall. 

## Purchasing a subscription

Tap the **Continue** button in the paywall and "purchase" a subscription. When the paywall dismisses, try triggering. You'll notice the buttons no longer show the paywall. The paywalls are only presented to users who haven't got an active subscription. To cancel the active subscription for an app that's using a storekit configuration file for testing, delete and reinstall the app.

## Support

For an in-depth explanation of how to use the *Paywall* SDK, you can [view our iOS SDK documentation](https://sdk.superwall.me/documentation/paywall/). If you'd like to view it in Xcode, select **Product ▸ Build Documentation**.

For general docs that include how to use the Superwall Dashboard, visit [docs.superwall.com](https://docs.superwall.com/docs).
