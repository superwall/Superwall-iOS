# Native macOS

Use SuperwallKit in AppKit and SwiftUI Mac apps on macOS 12 or later. Install with Swift Package Manager and configure the SDK with the same API as on iOS:

```swift
import SuperwallKit

Superwall.configure(apiKey: "YOUR_PUBLIC_API_KEY")
Superwall.shared.register(placement: "campaign_trigger") {
  // Unlock the feature after the campaign allows access.
}
```

For a sandboxed Mac app, enable outgoing network connections (`com.apple.security.network.client`). Add the appropriate usage descriptions and sandbox entitlements for any camera, microphone, contacts, photos or location permissions your paywall requests. Configure App Store products for the Mac app, or provide your own purchase controller. StoreKit purchases require the app's own product and signing configuration.

CocoaPods requires Superscript 1.0.16 or later for its macOS platform declaration. Until that dependency is published, use Swift Package Manager.

## Presentation

`PaywallViewController` inherits from `NSViewController` on macOS. Public presenter parameters and `presentedViewController` use `PlatformViewController`, an alias for `NSViewController` on macOS and `UIViewController` on UIKit platforms. `PaywallView` embeds the native controller in SwiftUI.

| Style | Native Mac behavior |
| --- | --- |
| Modal | A 480 × 720 point sheet, reduced to fit the screen |
| Drawer | A sheet using the configured height percentage, with a 320 point minimum |
| Fullscreen / fullscreenNoAnimation | Covers the host window's content, with or without animation |
| Push | Covers the host window's content, sliding from the trailing edge |
| Popup | A proportionally sized card over a dimmed backdrop |

The SDK uses the active window. A menu bar app without a presentable window gets a separate paywall window. Overlay windows follow their host's size and position; closing the host dismisses the paywall. Escape dismisses modal and drawer sheets. Popup backdrop clicks dismiss the popup. Closing follows the normal paywall lifecycle, feature gating and survey flow.

Full screen means the window's content area, not macOS full-screen mode. Design paywalls to respond to different aspect ratios. Use `device.platform == "macOS"` or `device.interfaceType == "mac"` in campaign rules to choose Mac layouts.

## Purchases and Customer Center

StoreKit, external purchase controllers, restoration, web checkout and redemption use the shared SDK pipeline. Embedded web checkout opens a native sheet. Other links open in the user's default browser. Teleport return links are forwarded to the paywall page; forward your app’s incoming URLs to `Superwall.handleDeepLink(_:)`.

Present Customer Center with `Superwall.shared.presentCustomerCenter()`, embed `CustomerCenterView`, or use `CustomerCenterViewController`. Subscription management opens the App Store subscriptions page. Refund requests and the native change-plan view require macOS 14; those actions are hidden on older versions. Appearance configuration accepts `NSColor` on macOS.

## Development

Test Mode includes native starting-entitlement, simulated purchase and restore sheets. Dashboard debug links and `superwall dev` links open a Mac preview window with paywall selection, locale and free-trial overrides. Forward URLs to `Superwall.handleDeepLink(_:)`, for example with SwiftUI's `.onOpenURL`. The UIKit debugger's template console and local-resource inspector are not part of the native preview window.

The SDK reports native Macs and Mac Catalyst as `isMac = true`. Native macOS uses an app-scoped UUID persisted in UserDefaults for SDK device identity. It is not Apple's IDFV and is not sent as an IDFV to attribution partners. MMP install matching is skipped on native macOS because its backend currently supports only iOS and Android. Screen dimensions are in points. Haptics use the trackpad when supported.

The example in `Examples/macOS` demonstrates a native SwiftUI app and Customer Center. The `SuperwallKitMac` scheme builds the framework and runs native presentation regression tests.
