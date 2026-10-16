# Native macOS example

Requires Xcode 26 and macOS 13 or later (the SDK itself supports macOS 12).

```sh
cd Examples/macOS
xcodegen
open SuperwallMacExample.xcodeproj
```

Run the `SuperwallMacExample` scheme. The sample uses the Basic example's public demo API key and `non_gated_pro` placement. Replace both for your app. Enable Test Mode in your dashboard to simulate purchases without StoreKit product configuration.

The app demonstrates campaign presentation, Customer Center, deep-link handling, and SDK events. Open another window to exercise presentation from the active window. The sandbox entitlements enable outgoing networking.

The main repository's `SuperwallKitMac` scheme runs native window regression tests:

```sh
xcodegen
xcodebuild -project SuperwallKit.xcodeproj -scheme SuperwallKitMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```
