# `SuperwallKit`

The client SDK for [Superwall](https://superwall.com), a service that lets you remotely configure, present and iterate paywalls – helping you find winners quickly.

## Overview

Superwall makes it easy to show paywalls in your app using UIKit or SwiftUI. If you haven't already, [sign up for a free Superwall account](https://superwall.com/sign-up). Configure the SDK with your API key and present our example paywall in response to a registered placement. When you're ready to use your own paywalls, head to the Superwall dashboard and use the paywall editor to configure them. Then, create a Campaign and define audiences to determine when to show paywalls to users.

See our [docs](https://docs.superwall.com/docs) for more information.

### Extending the paywall web view

Set ``Superwall/paywallWebViewCreated`` before configuring the SDK to receive each paywall's `WKWebView` as soon as it's created, before it loads anything. Add-ons plug in this way without SuperwallKit depending on them. For example, NativeIslands draws native views in your paywalls:

```swift
NativeIslandsComponents.register()
Superwall.paywallWebViewCreated = { NativeIslandsHost.attach(to: $0) }
```

## Topics

### Essentials

- `SuperwallKit/Superwall`
- `SuperwallOptions`

### Extending the Paywall Web View

- ``Superwall/paywallWebViewCreated``

### The Delegate

- `SuperwallDelegate`
- `PurchaseController`

### Customer Center

- <doc:CustomerCenter>
- `CustomerCenterConfiguration`
- `CustomerCenterDelegate`

## Native Mac apps

- <doc:macOS>

## watchOS and tvOS apps

- <doc:WatchAndTV>
