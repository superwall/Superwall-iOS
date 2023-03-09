<p align="center">
  <br />
  <img src=https://user-images.githubusercontent.com/3296904/158817914-144c66d0-572d-43a4-9d47-d7d0b711c6d7.png alt="logo" height="100px" />
  <h3 style="font-size:26" align="center">In-App Paywalls Made Easy 💸</h3>
  <br />
</p>

<p align="center">
  <a href="https://docs.superwall.com/docs/installation-via-spm">
    <img src="https://img.shields.io/badge/SwiftPM-Compatible-orange" alt="SwiftPM Compatible">
  </a>
  <a href="https://docs.superwall.com/docs/installation-via-cocoapods">
    <img src="https://img.shields.io/badge/pod-compatible-informational" alt="Cocoapods Compatible">
  </a>
  <a href="https://superwall.com/">
    <img src="https://img.shields.io/badge/ios%20version-%3E%3D%2013.0-blueviolet" alt="iOS Versions Supported">
  </a>
  <a href="https://github.com/superwall-me/Superwall-iOS/blob/master/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-green/" alt="MIT License">
  </a>
  <a href="https://superwall.com/">
    <img src="https://img.shields.io/badge/community-active-9cf" alt="Community Active">
  </a>
  <a href="https://superwall.com/">
    <img src="https://img.shields.io/github/v/tag/superwall-me/Superwall-iOS" alt="Version Number">
  </a>
</p>

----------------

[Superwall](https://superwall.com/) lets you remotely configure every aspect of your paywall — helping you find winners quickly.

## Paywall.framework (currently supported)
We're in the process of releasing a new v3 version of the framework called **SuperwallKit.framework**. It's currently in beta status. If you don't want to use the beta, please use **Paywall.framework**, which is available on version 2.x.

## Migrating to v3

- See our [Migration Guide](https://docs.superwall.com/v3.0/docs/migrating-to-v3)

## SuperwallKit.framework Beta

**SuperwallKit** and **Paywall** are clients for Superwall's remote paywall configuration platform.

**Paywall** is the currently supported, production-ready, open source framework that provides a wrapper around `WebKit` for presenting and creating paywalls. It interacts with the Superwall backend letting you easily iterate paywalls on the fly in `Swift` or `Objective-C`!

**SuperwallKit** is our next big release. It is a rename of `Paywall` to `SuperwallKit` and contains a lot of breaking changes. You can see the changes in our [changelog](CHANGELOG.md).

## Features
|   | Superwall |
| --- | --- |
✅ | Server-side paywall iteration
🎯 | Paywall conversion rate tracking - know whether a user converted after seeing a paywall
🆓 | Trial start rate tracking - know and measure your trial start rate out of the box
📊 | Analytics - automatic calculation of metrics like conversion and views
✏️ | A/B Testing - automatically calculate metrics for different paywalls
📝 | [Online documentation](https://docs.superwall.com/v3.0/docs) up to date
🔀 | [Integrations](https://docs.superwall.com/v3.0/docs) - over a dozen integrations to easily send conversion data where you need it
💯 | Well maintained - [frequent releases](https://github.com/superwall-me/Superwall-iOS/releases)
📮 | Great support - email a founder: jake@superwall.com

## Installation

### Swift Package Manager

The preferred installation method is with [Swift Package Manager](https://swift.org/package-manager/). This is a tool for automating the distribution of Swift code and is integrated into the swift compiler. In Xcode, do the following:

- Select **File ▸ Add Packages...**
- Search for `https://github.com/superwall-me/Superwall-iOS` in the search bar.
- Set the **Dependency Rule** to **branch** with the value set to **master**. If you're wanting to install v2.x, set the **Dependency Rule** to **Up to Next Major Version** with the lower bound set to **2.0.0**.
- Make sure your project name is selected in **Add to Project**.
- Then, **Add Package**.

### Cocoapods

[Cocoapods](https://cocoapods.org) is an alternative dependency manager for iOS projects. For usage and installation instructions, please visit their website.
To include the *Superwall* SDK in your app, add the following to your Podfile:

```
pod 'SuperwallKit', '3.0.0-beta.7'
```

If you don't want to use the v3 beta, you'll need to add this instead:

```
pod 'Paywall', '< 3.0.0'
```

Then, run `pod install`.

## Getting Started

### With v3

[Sign up for a free account on Superwall](https://superwall.com/sign-up) and [read our docs](https://docs.superwall.com/v3.0/docs).

You can also [view our iOS SDK docs](https://sdk.superwall.me/documentation/superwallkit/). If you'd like to view it in Xcode, select **Product ▸ Build Documentation**.

Check out our sample apps for a hands-on demonstration of the SDK:

- [Swift-UIKit with RevenueCat Example App](Examples/UIKit+RevenueCat)
- [Swift-UIKit with StoreKit Example App](Examples/UIKit-Swift)
- [SwiftUI Example App](Examples/SwiftUI)
- [Objective-C-UIKit](Examples/UIKit+RevenueCat)

### With v2

[Sign up for a free account on Superwall](https://superwall.com/sign-up) and [read our docs](https://docs.superwall.com/docs).

You can also [view our iOS SDK docs](https://sdk.superwall.me/documentation/paywall/).

Read our Kodeco (Ray Wenderlich) tutorial: [Superwall: Remote Paywall Configuration on iOS](https://www.kodeco.com/31484602-superwall-remote-paywall-configuration-on-ios)

## Contributing

Please see the [CONTRIBUTING](.github/CONTRIBUTING.md) file for how to help.
