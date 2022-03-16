<p align="center" style="background-color: #0D1116; padding: 40px; corner-radius: 15px;">
    <br>
    <img src="https://repository-images.githubusercontent.com/388287766/ed5c47aa-491f-4d70-9ea7-ec09ad4a03fa" alt="logo" height="200px" align="center" />
</p>

<h3 align="center">In-App Paywalls Made Easy 💸</h3>

<p align="center">
  [![License MIT](https://img.shields.io/badge/license-MIT-green/)](https://superwall.com/)
  [![SwiftPM Compatible](https://img.shields.io/badge/SwiftPM-Compatible-orange)](https://superwall.com/)
  [![Pod Compatible](https://img.shields.io/badge/pod-compatible-informational)](https://superwall.com/)
  [![Community Active](https://img.shields.io/badge/community-active-9cf)](https://superwall.com/)
  [![Version Number](https://img.shields.io/github/v/tag/superwall-me/paywall-ios)](https://superwall.com/)
  [![Versions Supported](https://img.shields.io/badge/ios%20version-%3E%3D%2011-blueviolet)](https://superwall.com/)
</p>
----------------

[Superwall](https://superwall.com/) lets you remotely configure every aspect of your paywall — helping you find winners quickly.

## Paywall.framework

**Paywall** is the open source SDK for [Superwall](https://superwall.com/), providing a wrapper around `Webkit` for presenting and creating paywalls. The Superwall backend for implementing new paywalls lets you iterate on the fly in `Swift` or `Objective-C` easily!

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

## Examples

Check out these example apps with the *Paywall* SDK installed.

- [Swift - SwiftUI](Example)
- [Swift – UIKit](https://github.com/superwall-me/superwallQuickStart)
- [Objective-C](https://github.com/superwall-me/SuperwallQuickstartObjectiveC)

## Installation

### Swift Package Manager

The preferred installation method is with [Swift Package Manager](https://swift.org/package-manager/). This is a tool for automating the distribution of Swift code and is integrated into the swift compiler. In Xcode, do the following:

- File > Swift Packages > Add Package Dependency
- Add `https://github.com/superwall-me/paywall-ios`
- Select "Up to Next Major" with "2.0.0"

### Cocoapods

[Cocoapods](https://cocoapods.org) is an alternative dependency manager for iOS projects. For usage and installation instructions, please visit their website.
Add the following to your Podfile:

```
pod 'Paywall', '< 3.0.0'
```

## Getting Started
For more detailed information, you can view our complete documentation at [docs.superwall.com](https://docs.superwall.com/docs).

Check out our [SwiftUI example app](Examples/)

Or, get started with [an example app](https://github.com/superwall-me/superwallQuickStart). 

<!-- Or browse our iOS sample apps:
- [Example Repos](github.com/re) -->

<!-- ➡️ | [Webhooks](https://docs.superwall.com/docs/webhooks) - enhanced server-to-server communication with events for purchases, renewals, cancellations, and more -->
