# SwiftUI Example App

This app demonstrates how to use SuperwallKit in SwiftUI. We've written a mini tutorial below to help you understand what's going on in the app.

Usually, to integrate SuperwallKit into your app, you first need to have configured a paywall using the [Superwall Dashboard](https://superwall.com/dashboard). However, with this example app, we have already done that for you and provided a sample API key to get you up and running. When you integrate the SDK into your own app, you'll need to use your own API key for your own Superwall account. To do that, [sign up for a free account on Superwall](https://superwall.com/sign-up).

## Features

Feature | Sample Project Location
--- | ---
🕹 Configuring SuperwallKit | [Services/SuperwallService.swift](Superwall-SwiftUI/Services/SuperwallService.swift#L31)
👥 Implementing the delegate | [Services/SuperwallService.swift](Superwall-SwiftUI/Services/SuperwallService.swift#L67)
👉 Tracking an event | [TrackEventModel.swift](Superwall-SwiftUI/TrackEventModel.swift#L15)
👥 Identifying account | [Services/SuperwallService.swift](Superwall-SwiftUI/Services/SuperwallService.swift#L31)
👥 Resetting account | [Services/SuperwallService.swift](Superwall-SwiftUI/Services/SuperwallService.swift#L54)

## Requirements

This example app uses:

- SwiftUI
- Xcode 14
- iOS 16
- Swift 5.5

You'll need to have SwiftLint installed. If you use Homebrew to install packages on your computer you run the following in the command line:

`brew install swiftlint`

Otherwise, you can download it from [https://github.com/realm/SwiftLint](https://github.com/realm/SwiftLint).

## Getting Started

Clone or download the SuperwallKit from the [project home page](https://github.com/superwall-me/Superwall-iOS). Then, open **Superwall-SwiftUI.xcodeproj** in Xcode and take a look at the code inside the [Superwall-SwiftUI](Superwall-SwiftUI) folder.

Inside the [Services](Superwall-SwiftUI/Services) folder, you'll see some helper classes. [SuperwallService.swift](Superwall-SwiftUI/Services/SuperwallService.swift) handles the setup and delegate methods of the SDK. All subscription-related logic is handled by the SDK but we have included a (commented out) example of how you might implement purchases yourself using StoreKit in [StoreKitService.swift](Superwall-SwiftUI/Services/StoreKitService.swift).

[Superwall_SwiftUI-Products.storekit](Superwall-SwiftUI/Superwall_SwiftUI-Products.storekit) is a StoreKit configuration file that is used to mimic the setup of real products on App Store Connect. This is so you can make test purchases within the sample app without having to set up App Store Connect. In a production app, you will need real products configured in App Store Connect but you can also use a StoreKit configuration file for testing purposes if you wish.

You'll see a few different SwiftUI files that handle the layout of the app and presenting of paywalls.

Build and run the app and you'll see the welcome screen:

<p align="center">
  <img src="https://i.imgur.com/jKkBBNW.png" alt="The welcome screen" width="220px" />
</p>

SuperwallKit is [configured](Superwall-SwiftUI/Services/SuperwallService.swift#L31) on app launch, setting an `apiKey` and `delegate`.

The SDK sends back events received from the paywall via the delegate methods in [SuperwallService.swift](Superwall-SwiftUI/Services/SuperwallService.swift#L67). You use these methods to make and restore purchases and react to analytical events.

## Logging In

On the welcome screen, enter your name in the **text field**. This saves to the Superwall user attributes using [Superwall.shared.setUserAttributes(_:)](Superwall-SwiftUI/Services/SuperwallService.swift#L62). You don't need to set user attributes, but it can be useful if you want to create a rule to present a paywall based on a specific attribute you've set. You can also recall user attributes on your paywall to personalise the messaging.

Tap **Log In**. This identifies the user (with a hardcoded userId that we've set), retrieving any paywalls that have already been assigned to them.

You'll see an overview screen:

<p align="center">
  <img src="https://i.imgur.com/P3dYPuZ.png" alt="The overview screen" width="220px" />
</p>

## Presenting a Paywall

To present a paywall, you **track** an event. 

On the [Superwall Dashboard](https://superwall.com/dashboard) you add this event to a Campaign and attach some presentation rules. For this app, we've already done this for you.

When an event is tracked, SuperwallKit evaluates the rules associated with it to determine whether or not to show a paywall.

By calling [Superwall.shared.track(event:params:paywallOverrides:paywallHandler:)](Superwall-SwiftUI/TrackEventModel.swift#L15), you present a paywall in response to the event. For this app, the event is called `campaign_trigger`.

On screen you'll see some explanatory text and a button that tracks an event:

<p align="center">
  <img src="https://user-images.githubusercontent.com/3296904/158836596-10d00960-50b8-4fd0-a36f-dd484a305d22.png" alt="Explicitly triggering a paywall" width="220px" />
</p>

Tap the **Track Event** button and you'll see the paywall. If the event is disabled on the dashboard, the paywall wouldn't show.

## Purchasing a subscription

Tap the **Continue** button in the paywall and "purchase" a subscription. When the paywall dismisses, try tracking an event. You'll notice the buttons no longer show the paywall. The paywalls are only presented to users who haven't got an active subscription. To cancel the active subscription for an app that's using a storekit configuration file for testing, delete and reinstall the app.

## Support

For an in-depth explanation of how to use the SuperwallKit, you can [view our iOS SDK documentation](https://sdk.superwall.me/documentation/superwallkit/). If you'd like to view it in Xcode, select **Product ▸ Build Documentation**.

For general docs that include how to use the Superwall Dashboard, visit [docs.superwall.com](https://docs.superwall.com/docs).
