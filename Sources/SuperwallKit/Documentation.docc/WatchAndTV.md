# watchOS and tvOS

Use SuperwallKit in watchOS 8+ and tvOS 15+ apps to track purchases, subscription status and entitlements. Install with Swift Package Manager and configure the SDK with the same API as on iOS:

```swift
import SuperwallKit

let options = SuperwallOptions()
options.shouldObservePurchases = true
Superwall.configure(apiKey: "YOUR_PUBLIC_API_KEY", options: options)
```

## What's available

Configuring, identifying users, user attributes, placements, purchases, restores, observer mode, subscription status, entitlements, `CustomerInfo`, web checkout redemption and the `SuperwallDelegate` work as on iOS.

Neither platform has a web view, so paywalls, the debugger, Test Mode and Customer Center aren't available. The APIs that only make sense with a paywall on screen, such as `getPaywall` and `PaywallView`, don't exist on these platforms.

## Placements

`register(placement:)` still runs the campaign's audience filters:

- A holdout, or a placement with no matching audience, is skipped and runs the feature, as on iOS.
- When a paywall would be shown, it's treated as a paywall that failed to load, as on iOS without an internet connection. The handler's `onDismiss` gets a declined result, with no `onPresent` before it. A non-gated feature runs. A gated feature doesn't, and the handler's `onError` gets an error instead. If the paywall itself can't be fetched, `onError` gets that error.

`getPresentationResult(forPlacement:)` returns the paywall the user would see. Implicit placements, such as `app_launch`, don't trigger anything.

## Platform differences

- tvOS: audience filters don't match yet, because the rules engine has no tvOS build. Audiences without a filter still match. Local notifications, such as free trial reminders, aren't scheduled because tvOS notifications can't show text.
- watchOS: the connection type is reported as `Unknown`. The device's interface type is `watch`.
- MMP install matching and Apple Search Ads attribution don't run on either platform.
- CocoaPods doesn't install SuperwallKit on these platforms.
