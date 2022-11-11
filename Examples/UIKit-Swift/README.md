# UIKit Example App

This app demonstrates how to use SuperwallKit with UIKit. We've written a mini tutorial below to help you understand what's going on in the app.

Usually, to integrate SuperwallKit into your app, you first need to have configured a paywall using the [Superwall Dashboard](https://superwall.com/dashboard). However, with this example app, we have already done that for you and provided a sample API key to get you up and running. When you integrate the SDK into your own app, you'll need to use your own API key for your own Superwall account. To do that, [sign up for a free account on Superwall](https://superwall.com/sign-up).

## Features

Feature | Sample Project Location 
--- | ---
🕹 Configuring SuperwallKit | [Services/SuperwallService.swift](Superwall-UIKit/Services/SuperwallService.swift#L22)
👉 Presenting a paywall | [ImplicitlyTriggerPaywallViewController.swift](Superwall-UIKit/TrackEventViewController.swift#L59)
👥 Logging In | [Services/SuperwallService.swift](Superwall-UIKit/Services/SuperwallService.swift#L30)
👥 Logging Out | [Services/SuperwallService.swift](Superwall-UIKit/Services/SuperwallService.swift#L45)

## Requirements

This example app uses:

- UIKit
- Xcode 14
- iOS 16
- Swift 5.5

You'll need to have SwiftLint installed. If you use Homebrew to install packages on your computer you run the following in the command line:

`brew install swiftlint`

Otherwise, you can download it from [https://github.com/realm/SwiftLint](https://github.com/realm/SwiftLint).

## Getting Started

Clone or download SuperwallKit from the [project home page](https://github.com/superwall-me/paywall-ios). Then, open **Superwall-UIKit.xcodeproj** in Xcode and take a look at the code inside the [Superwall-UIKit]() folder.

Inside the [Services](Superwall-UIKit/Services) folder, you'll see some helper classes. [SuperwallService.swift](Superwall-UIKit/Services/SuperwallService.swift) handles the setup and delegate methods of the SDK, and [StoreKitService.swift](Superwall-UIKit/Services/StoreKitService.swift) handles the purchasing of in-app subscriptions.

[Products.storekit](Superwall-UIKit/Products.storekit) is a StoreKit configuration file that is used to mimic the setup of real products on App Store Connect. This is so you can make test purchases within the sample app without having to set up App Store Connect. In a production app, you will need real products configured in App Store Connect but you can also use a StoreKit configuration file for testing purposes if you wish.

You'll see [Main.storyboard](Superwall-UIKit/Base.lproj/Main.storyboard) specifies the the layout of the app and other swift files handle the presentation of Paywalls.

Build and run the app and you'll see the welcome screen:

<p align="center">
  <img src="https://user-images.githubusercontent.com/3296904/161958142-c2f195b9-bd43-4f4e-9521-87c6fe4238ec.png" alt="The welcome screen" width="220px" />
</p>

SuperwallKit is [configured](Superwall-UIKit/Services/SuperwallService.swift#L20) on app launch, setting an `apiKey` and `delegate`.

The SDK sends back events received from the paywall via the delegate methods in [SuperwallService.swift](Superwall-UIKit/Services/SuperwallService.swift). You use these methods to make and restore purchases, react to analytical events, as well as tell the SDK whether the user has an active subscription. 

## Logging In

On the welcome screen, enter your name in the **text field**This saves to the Superwall user attributes using [Superwall.setUserAttributes(_:)](Superwall-UIKit/Services/SuperwallService.swift#L63). You don't need to set user attributes, but it can be useful if you want to create a rule to present a paywall based on a specific attribute you've set. You can also recall user attributes on your paywall to personalise the messaging.

Tap **Log In**. This logs the user in to Superwall (with a hardcoded userId that we've set), retrieving any paywalls that have already been assigned to them. If you were to create a new account you'd use `Superwall.createAccount(userId:)` instead.


You'll see an overview screen:

<p align="center">
  <img src="https://user-images.githubusercontent.com/3296904/161960829-dfdc1319-571a-4784-b18f-bbb8c07f5a65.png" alt="The overview screen" width="220px" />
</p>

## Presenting a Paywall

To present a paywall, you **track** an event. 

On the [Superwall Dashboard](https://superwall.com/dashboard) you add this event to a Campaign and attach some presentation rules. For this app, we've already done this for you.

When an event is tracked, SuperwallKit evaluates the rules associated with it to determine whether or not to show a paywall. Note that if the delegate method [isUserSubscribed()](Superwall-UIKit/SuperwallService.swift#L82) returns `true`, a paywall will not show by default.

By calling [Superwall.track(event:params:paywallOverrides:paywallState:)](Superwall-UIKit/TrackEventViewController.swift#L57), you present a paywall in response to the event. For this app, the event is called "MyEvent".

On screen you'll see some explanatory text and a button that tracks an event:

<p align="center">
  <img src="https://user-images.githubusercontent.com/3296904/161961942-2b7ccf40-83d1-47c5-8f49-6fb409b17491.png" alt="Presenting a paywall" width="220px" />
</p>

Tap the **Track Event** button and you'll see the paywall. If the event is disabled on the dashboard, the paywall wouldn't show.

## Purchasing a subscription

Tap the **Continue** button in the paywall and "purchase" a subscription. When the paywall dismisses, try tracking an event. You'll notice the buttons no longer show the paywall. The paywalls are only presented to users who haven't got an active subscription. To cancel the active subscription for an app that's using a storekit configuration file for testing, delete and reinstall the app.

## Support

For an in-depth explanation of how to use SuperwallKit, you can [view our iOS SDK documentation](https://sdk.superwall.me/documentation/paywall/). If you'd like to view it in Xcode, select **Product ▸ Build Documentation**.

For general docs that include how to use the Superwall Dashboard, visit [docs.superwall.com](https://docs.superwall.com/docs).
