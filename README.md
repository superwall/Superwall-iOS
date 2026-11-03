<p align="center">
  <img src="https://user-images.githubusercontent.com/3296904/158817914-144c66d0-572d-43a4-9d47-d7d0b711c6d7.png" alt="Superwall" height="80" />
</p>

<h1 align="center">SuperwallKit</h1>

<p align="center">
  AI-powered paywalls, subscriptions and experiments for iOS and Mac apps.
</p>

<p align="center">
  <a href="https://github.com/superwall/Superwall-iOS/releases">
    <img src="https://img.shields.io/github/v/release/superwall/Superwall-iOS?label=SDK&color=555555&labelColor=212223" alt="Latest SDK version" />
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-555555?labelColor=212223" alt="MIT license" />
  </a>
  <a href="https://www.emergetools.com/app/example/ios/SuperwallKit/release?utm_campaign=badge-data">
    <img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fwww.emergetools.com%2Fapi%2Fv2%2Fpublic_new_build%3FexampleId%3DSuperwallKit%26platform%3Dios%26badgeOption%3Dmax_install_size_only%26buildType%3Drelease&query=$.badgeMetadata&label=SuperwallKit&logo=apple" alt="SDK size" />
  </a>
</p>

<p align="center">
  <a href="#add-superwall-with-a-single-prompt">Get started</a> ·
  <a href="https://superwall.com/docs/ios">Docs</a> ·
  <a href="https://sdk.superwall.me/documentation/superwallkit/">API reference</a> ·
  <a href="#examples">Examples</a>
</p>

## Add Superwall with a single prompt

Paste this into your coding agent. It installs the SDK, sets up entitlements and adds your first paywall.

```text
Install Superwall into my app using the skill at github.com/superwall/skills
```

Prefer a guided setup? Run this from your app’s folder. It signs you up or in, then runs Claude Code or Codex for you:

```bash
npx superwall integrate
```

Read the [agent integration guide](https://superwall.com/docs/agents/integrate-the-sdk) for details.

<details>
<summary>Moving from a different platform?</summary>

Run this. It follows the same steps, starting from your existing setup:

```bash
superwall migrate
```

</details>

## Manual quick start

Install and configure the SDK yourself. Requires Xcode 26 or later.

### 1. Install the SDK

In Xcode, choose **File ▸ Add Package Dependencies…** and add this URL, using **Up to Next Major Version** from **4.0.0**:

```text
https://github.com/superwall/Superwall-iOS
```

<details>
<summary>Install with CocoaPods</summary>

Add this to your Podfile:

```ruby
pod 'SuperwallKit', '< 5.0.0'
```

Then run:

```bash
pod install --repo-update
```

</details>

### 2. Configure the SDK

[Create a Superwall account](https://superwall.com/sign-up) and copy your app’s public API key from the dashboard. Call `configure` once when your app launches:

```swift
import SuperwallKit

Superwall.configure(apiKey: "YOUR_PUBLIC_API_KEY")
```

### 3. Register a placement

A placement is a named point in your app where a campaign can show a paywall. On the dashboard, add the `premium_feature` placement to a campaign and give it a paywall. Then call this where someone opens the feature:

```swift
Superwall.shared.register(placement: "premium_feature") {
  // Open your feature here.
}
```

The campaign decides whether a paywall shows. With no paywall set up, the closure runs straight away. See the [iOS guide](https://superwall.com/docs/ios) for purchases and testing.

## Platforms

| Platform | Support |
| --- | --- |
| iOS | iOS 15+ · UIKit and SwiftUI |
| macOS | macOS 12+ · native AppKit and SwiftUI · [Mac guide](Sources/SuperwallKit/Documentation.docc/macOS.md) |
| Mac Catalyst · visionOS | Uses the iOS API |

## What you get

- Update paywalls from the dashboard without releasing a new app version.
- Choose which paywall to show with campaigns and audience rules.
- Run A/B tests across paywalls.
- Track paywall views, trial starts and conversions.
- Control access to features with placements.

## Examples

- [Basic](Examples/Basic): a starting integration.
- [Advanced](Examples/Advanced): purchase controllers, user attributes and delegates.
- [macOS](Examples/macOS): a native SwiftUI Mac app.

## Upgrading

See the [release notes](https://github.com/superwall/Superwall-iOS/releases) for changes between versions.

<details>
<summary>Upgrade from V3 to V4</summary>

Follow the [V4 migration guide](https://superwall.com/docs/migrating-to-v4).

</details>

## Support and contributing

[Read the docs](https://superwall.com/docs/ios) for setup help, or [report a bug](https://github.com/superwall/Superwall-iOS/issues) with your SDK version and steps to reproduce it. To contribute, read the [contributing guide](.github/CONTRIBUTING.md).

SuperwallKit is available under the [MIT license](LICENSE).
