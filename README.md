<p align="center" style="padding:20px">
  <img src=https://user-images.githubusercontent.com/3296904/158817914-144c66d0-572d-43a4-9d47-d7d0b711c6d7.png alt="logo" height="100px" align="center" />
  <h2 align="center">Double your revenue 💸</h2>
</p>

<p align="center">
  <a href="https://docs.superwall.com/docs/installation-via-spm">
    <img src="https://img.shields.io/badge/SwiftPM-Compatible-orange" alt="SwiftPM Compatible">
  </a>
  <a href="https://docs.superwall.com/docs/installation-via-cocoapods">
    <img src="https://img.shields.io/badge/pod-compatible-informational" alt="Cocoapods Compatible">
  </a>
  <a href="https://superwall.com/">
    <img src="https://img.shields.io/badge/ios%20version-%3E%3D%2011-blueviolet" alt="iOS Versions Supported">
  </a>
  <a href="https://github.com/superwall-me/paywall-ios/blob/master/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-green/" alt="MIT License">
  </a>
  <a href="https://superwall.com/">
    <img src="https://img.shields.io/badge/community-active-9cf" alt="Community Active">
  </a>
  <a href="https://superwall.com/">
    <img src="https://img.shields.io/github/v/tag/superwall-me/paywall-ios" alt="Version Number">
  </a>
</p>

----------------

[Superwall](https://superwall.com/) lets you remotely configure every aspect of your paywall — helping you find winners quickly.

## Paywall.framework

**Paywall** is the open source SDK for Superwall, providing a wrapper around `Webkit` for presenting and creating paywalls. It interacts with the Superwall backend letting you easily iterate paywalls on the fly in `Swift` or `Objective-C`!

## Features
|   | Superwall |
| --- | --- |
✅ | Server-side paywall iteration
🎯 | Paywall conversion rate tracking - know whether a user converted after seeing a paywall
🆓 | Trial start rate tracking - know and measure your trial start rate out of the box
📊 | Analytics - automatic calculation of metrics like conversion and views
✏️ | A/B Testing - automatically calculate metrics for different paywalls
📝 | [Online documentation](https://docs.superwall.com/docs) up to date
🔀 | [Integrations](https://docs.superwall.com/docs) - over a dozen integrations to easily send conversion data where you need it
🖥 | macOS support
💯 | Well maintained - [frequent releases](https://github.com/superwall-me/paywall-ios/releases)
📮 | Great support - email a founder: justin@superwall.com

## Installation

### Swift Package Manager

The preferred installation method is with [Swift Package Manager](https://swift.org/package-manager/). This is a tool for automating the distribution of Swift code and is integrated into the swift compiler. In Xcode, do the following:

- File > Swift Packages > Add Package Dependency
- Add `https://github.com/superwall-me/paywall-ios`
- Select "Up to Next Major" with "2.0.0"

### Cocoapods

[Cocoapods](https://cocoapods.org) is an alternative dependency manager for iOS projects. For usage and installation instructions, please visit their website.
To include the *Paywall* SDK in your app, add the following to your Podfile:

```
pod 'Paywall', '< 3.0.0'
```

## Getting Started

Check out our sample apps:

- [Swift - SwiftUI](Example)
- [Swift – UIKit](https://github.com/superwall-me/superwallQuickStart)
- [Objective-C](https://github.com/superwall-me/SuperwallQuickstartObjectiveC)

For more detailed information, you can view our complete documentation at [docs.superwall.com](https://docs.superwall.com/docs).

<!-- ➡️ | [Webhooks](https://docs.superwall.com/docs/webhooks) - enhanced server-to-server communication with events for purchases, renewals, cancellations, and more -->
