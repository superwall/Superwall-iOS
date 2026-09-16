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
  <a href="https://github.com/superwall/Superwall-iOS/blob/master/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-green/" alt="MIT License">
  </a>
  <a href="https://superwall.com/">
    <img src="https://img.shields.io/badge/community-active-9cf" alt="Community Active">
  </a>
  <a href="https://superwall.com/">
    <img src="https://img.shields.io/github/v/tag/superwall/Superwall-iOS" alt="Version Number">
  </a>
  <a href="https://www.emergetools.com/app/example/ios/SuperwallKit/release?utm_campaign=badge-data">
    <img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fwww.emergetools.com%2Fapi%2Fv2%2Fpublic_new_build%3FexampleId%3DSuperwallKit%26platform%3Dios%26badgeOption%3Dmax_install_size_only%26buildType%3Drelease&query=$.badgeMetadata&label=SuperwallKit&logo=apple" />
  </a>
</p>

----------------

[Superwall](https://superwall.com/) lets you remotely configure every aspect of your paywall — helping you find winners quickly.

## SuperwallKit.framework

**SuperwallKit** is an open source framework that provides a wrapper around `WebKit` for presenting and creating paywalls. It interacts with the Superwall backend letting you easily iterate paywalls on the fly in `Swift` or `Objective-C`!

## Migrating to v4

- If you're upgrading from v3.x of our SDK, please follow our [Migration Guide](https://docs.superwall.com/docs/migrating-to-v4)

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
💯 | Well maintained - [frequent releases](https://github.com/superwall/Superwall-iOS/releases)
📮 | Great support - email a founder: jake@superwall.com

## Installation

### Swift Package Manager

The preferred installation method is with [Swift Package Manager](https://swift.org/package-manager/). This is a tool for automating the distribution of Swift code and is integrated into the swift compiler. In Xcode, do the following:

- Select **File ▸ Add Packages...**
- Search for `https://github.com/superwall/Superwall-iOS` in the search bar.
- Set the **Dependency Rule** to **Up to Next Major Version** with the lower bound set to **4.0.0**.
- Make sure your project name is selected in **Add to Project**.
- Then, **Add Package**.

### Cocoapods

[Cocoapods](https://cocoapods.org) is an alternative dependency manager for iOS projects. For usage and installation instructions, please visit their website.
To include the *Superwall* SDK in your app, add the following to your Podfile:

```
pod 'SuperwallKit', '< 5.0.0'
```

Next, run `pod repo update` to update your local spec repo.

Then, run `pod install` from your terminal.

## Getting Started

[Sign up for a free account on Superwall](https://superwall.com/sign-up) and [read our docs](https://docs.superwall.com/docs).

You can also [view our iOS SDK docs](https://sdk.superwall.me/documentation/superwallkit/). If you'd like to view it in Xcode, select **Product ▸ Build Documentation**.

Read our Kodeco (previously Ray Wenderlich) tutorial: [Superwall: Remote Paywall Configuration on iOS](https://www.kodeco.com/38677971-superwall-remote-paywall-configuration-on-ios).

Check out our sample apps for a hands-on demonstration of the SDK:

- [Basic Example App](Examples/Basic)
- [Advanced Example App](Examples/Advanced)

## Contributing

Please see the [CONTRIBUTING](.github/CONTRIBUTING.md) file for how to help.

### Device IP observations

During enrichment, the SDK also starts a best-effort request to
`https://v4.superwall-enrichment.com/api/v1/enrich`. It sends no user attributes or API key
to this endpoint. The existing enrichment API continues to provide geo and demand scoring.
It must also return the observed `ipV4` or `ipV6` and corresponding ISO 8601
`ipV4ObservedAt` / `ipV6ObservedAt` timestamp to capture that connection's address.

The SDK exposes `ipV4`, `ipV6`, `ipV4ObservedAt`, and `ipV6ObservedAt` as device
attributes when available. They remain separate: an IPv4 response does not erase IPv6.
IPv6 is opportunistic; a dual-stack enrichment request can use IPv4 even on a device
with IPv6. These are public network egress addresses, potentially shared through NAT or VPN.

The extra request never blocks configuration or purchases. Attempts are coalesced and
limited to one per 15 minutes when enrichment runs. The IPv4 collector is session-local; the existing enrichment cache may restore a still-fresh
observation after relaunch. All observations are omitted from device attributes after 15
minutes; network changes can make them stale sooner.
They are not proof of identity. Downstream consumers must preserve the timestamps and apply
their own freshness policy. Wrapper SDKs receive this behavior when they adopt a native
SDK release containing it.
