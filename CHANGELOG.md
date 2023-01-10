# CHANGELOG

The changelog for `Paywall`. Also see the [releases](https://github.com/superwall-me/paywall-ios/releases) on GitHub.

## 2.5.7

### Enhancements

- Adds `isExternalDataCollectionEnabled` data privacy `PaywallOption`. When `false`, prevents non-Superwall events and properties from being sent back to the superwall servers.
- Adds an `X-Is-Sandbox` header to all requests such that sandbox data doesn't affect your production analytics on superwall.com.

### Fixes

- Fixes a bug that prevented the correct calculation of a new app session.

---

## 2.5.6

### Fixes

- Fixes a bug found in the previous version. Disabling the preloading of paywalls for specific triggers via remote config now works correctly.

---

## 2.5.5

### Fixes

- Fixes a crash when all variants of a campaign rule are set to 0%.

### Enhancements

- Adds ablity to disable the preloading of paywalls from specific triggers via config.

---

## 2.5.4

### Fixes

- Fixes a crash issue where the completion blocks for triggering a paywall were being called on a background thread in a specific scenario.
- Fixes an issue where lazy properties were causing an occasional crash due to the use of multithreading.

---

## 2.5.3

### Fixes

- Fixes a bug where `Paywall.reset()` couldn't be called on a background thread.

---

## 2.5.2

### Fixes 

- Fixed memory and time issues associated with the shimmer view when loading a paywall. Special thanks to Martin from Planta for spotting that one. We've rebuilt the shimmer view and only add it when the paywall is visible and loading. This means it doesn't get added to paywalls preloading in the background. After loading, we remove the shimmer view from memory.
- Moves internal operations for templating paywall variables from the main thread to a background thread. This prevents hangs on the main thread.
- Stops UIAlertViewControllers being unnecessarily created when loading a paywall.
- Removes the dependency on `TPInAppReceipt` from our podspec and replaces it with a `ASN1Swift` dependency to keep it in line with our Swift Package file.

---

## 2.5.0

### Enhancements

- Assigments of paywall variants are now performed on device, meaning reduced network calls and faster setup time for the SDK.
- Adds `Paywall.latestPaywallInfo`. You can read this to access the `PaywallInfo` object of the most recently presented view controller.
- Adds feature flags under the hood so new features can be turned on for specific organizations and apps.
- Adds the ability to specify `SKProducts` with triggers. These override products defined in the dashboard. You do this by creating a `PaywallProducts` object and calling `Paywall.trigger(event: "event", products: products)`.
- Updates sample projects to iOS 16.

### Fixes 

- Shimmer view is no longer visible beneath a paywall's `WKWebView` when there is no `body` or `html` background color set
- Previously, calling `Paywall.preloadPaywalls(forTriggers:)` before `Paywall.config()` finished would not work. This has been fixed. 
- Previously, if a user purchases a product within a subscription group, they would still be offered a free trial on other products within that group. This has been fixed.
- Fixes a bug where `Paywall.reset()` couldn't be called on a background thread.

---

## 2.4.1

### Enhancements

- Adds `Paywall.preloadAllPaywalls()` and `Paywall.preloadPaywalls(forTriggers:)`. Use this with `Paywall.options.shouldPreloadPaywall = false` to have more control over when/what paywalls are preloaded.

### Fixes

- Paywall options specified prior to config are now respected, regardless of whether you pass an options object through to config or not.
- Ensures /config's request and response is always handled on the main thread

---

## 2.4.0

### Enhancements

- New _push_ presentation style. By selecting Push on the superwall dashboard, your paywall will push and pop in as if it's being pushed/popped from a navigation controller. If you are using UIKit, you can provide a view controller to `Paywall.trigger` like this: `Paywall.trigger(event: "MyEvent", on: self)`. This will make the push transition more realistic, by moving its view in the transition. Note: This is not backwards compatible with previous versions of the SDK.
- New _no animation_ presentation style. By selecting No Animation in the superwall dashboard, you can disable presentation/dismissal animation. This release deprecates `Paywall.shouldAnimatePaywallDismissal` and `Paywall.shouldAnimatePaywallPresentation`.
- A new `PaywallOptions` object that you configure and pass to `Paywall.configure(apiKey:userId:delegate:options) to override the default appearance and presentation of the paywall. This deprecates a lot of static variables for better organisation.
- New `shouldPreloadPaywalls` option. Set this to `false` to make paywalls load and cache in a just-in-time fashion. This replaces the old `Paywall.shouldPreloadTriggers` flag.
- New dedicated function for handling deeplinks: `Paywall.handleDeepLink(url)`.
- Deprecates old `track` functions. The only one you should use is `Paywall.track(_:_:)`, to which you pass an event name and a dictionary of parameters. Note: This is not backwards compatible with previous versions of the SDK.
- Adds a new way of internally tracking analytics associated with a paywall and the app session. This will greatly improve the Superwall dashboard analytics.
- Adds support for javascript expressions defined in rules on the Superwall dashboard.
- Updates the SDK documentation.
- Adds `trialPeriodEndDate` as a product variable. This means you can tell your users when their trial period will end, e.g. `Start your trial today — you won't be billed until {{primary.trialPeriodEndDate}}` will print out `Start your trial today — you won't be billed until June 21, 2023`.
- Adds support for having more than 3 products on your paywall.
- Exposes `Paywall.presentedViewController`. This gives you access to the `UIViewController` of the paywall incase you need to present a view controller on top of it.
- Adds `today`, `daysSinceInstall`, `minutesSinceInstall`, `daysSinceLastPaywallView`, `minutesSinceLastPaywallView` and `totalPaywallViews` as `device` parameters. These can be references in your rules and paywalls with `{{ device.paramName }}`.
- Paywalls can now be configured via the dashboard to always present, regardless of the subscription status of the user.
- Adds a `presentationStyleOverride` parameter to `Paywall.trigger()` and `Paywall.present()`. By setting this, you can override the configured presentation style on case by case basis.
- Rules can now be limited by occurrence and date. For example, you could set a rule to only match 10 times within the last 5 hours.
- Adds `Paywall.userId` to grab the id of the current user.
- Adds `$url`, `$path`, `$pathExtension`, `$lastPathComponent`, `$host`, `$query`, `$fragment` as standard parameters to the `deepLink_open` event trigger (automatically tracked).
- Parses URL parameters and adds them as trigger parameters to the `deepLink_open` event trigger (automatically tracked).
- Fixes window logic for opening the debugger and launching paywalls on `deepLink_open`.
- Launching a paywall using the `deepLink_open` Trigger now dismisses a currently presenting paywall before presenting the new one.

### Fixes

- Adds the missing Superwall events `app_install`, `paywallWebviewLoad_fail`, `paywallWebviewLoad_timeout` and `nonRecurringProduct_purchase`.
- Adds `trigger_name` to a `triggerFire` Superwall event, which can be accessed in the parameters sent back to the `trackAnalyticsEvent(name:params:)` delegate function.
- Product prices were being sent back to the dashboard with weird values like 89.999998. We fixed that.
- Modal presentation now uses `.pageSheet` instead of `.formSheet`. This results in a less compact paywall popover on iPad. Thanks to Daniel Yoo from the Daily Bible Inspirations app for spotting that!
- For SwiftUI users, we've fixed an issue where the explicitly triggered paywalls and presented paywalls would sometimes randomly dismiss. We found that state changes within the presenting view caused a rerendering of the view which temporarily reset the state of the binding that controlled the presentation of the paywall. This was causing the Paywall to dismiss.
- Fixes an issue where the wrong paywall was shown if a trigger was fired before the config was fetched from the server. Thanks to Zac from Blue Candy for help with finding that :)
- Future proofs enums internally to increase backwards compatibility.
- Fixes a bug where long term data was being stored in the cache directory. This update migrates that to the document directory. This means the data stays around until we tell it to delete, rather than the system deleting it at random.
- Prevents Paywall.configure from being called twice and logs a warning if this occurs.
- Prevents Paywall.configure from being called in the background.
- Fixes an issue where the keyboard couldn't be dismissed in the UIKit sample app.
- Mentions SwiftLint as a requirement to run the sample apps.
- Deprecates `Paywall.debugMode`. All logs are now controlled by setting the paywall option `.logLevel`. The default `logLevel` is now `.warn`.
- Fixes broken webview based deeplinks and closes the paywall view before calling the delegate handler.
- Deprecates `Paywall.present` for `Paywall.trigger`.
- Fixes issue where preloaded paywalls would be cleared upon calling `Paywall.identify()` if config was called without a `userId`.
- Fixes logic for grabbing the active view controller.

---

## 2.3.0

### Enhancements

- New [UIKit Example App](Examples/SuperwallUIKitExample).
- Better [SDK documentation](https://sdk.superwall.me/documentation/paywall/). This is built from the ground up using DocC which means you view it directly in Xcode by selecting **Product ▸ Build Documentation**.
- New Pull Request and Bug Report templates for the repo.
- Added a setup file that installs GitHooks as well as SwiftLint if you don't already have it. This is located at `scripts/setup.sh` and can be run from anywhere.
- Added a [CONTIBUTING.md](CONTRIBUTING.md) file for detailed instructions on how to get set up and contribute to the codebase.
- Added a [Code of Conduct](CODE_OF_CONDUCT.md) file to the repo.
- Added a CHANGELOG.md file.
- Removed the `TPInnAppReceipt` dependency for the SDK.

### Fixes

- All readme links for the UIKit example app now work.
- Adds an `experiment` parameter to `PaywallInfo`. This will be useful in the next version of Triggers, where you can see details about the experiment that triggered the presentation of the paywall.
- When triggering or presenting a paywall, if the default value for `isPresented` was `true`, the paywall would not present/trigger. It now works as expected.
