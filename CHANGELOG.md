# CHANGELOG

The changelog for `SuperwallKit`. Also see the [releases](https://github.com/superwall-me/Superwall-iOS/releases) on GitHub.

## 3.0.0-rc.6

### Breaking Changes

- Adds a `PaywallViewControllerDelegate` to the `getPaywallViewController` functions. This is mandatory and is how you control what happens after a paywall is dismissed.
- The completion block of `getPaywallViewController(forEvent:params:paywallOverrides:delegate:completion:)` now accepts an optional `PaywallViewController`, an optional `PaywallSkippedReason` and an optional `Error`. This makes it easier to understand when the paywall was skipped vs when a real error occurred.
- Renamed the `PaywallResult` case `closed` to `declined`.

### Enhancements

- Exposes `PaywallOverrides` and `PaywallViewController` to Objective-C.
- Adds Objective-C convenience methods to `PaywallOverrides`.
- Adds a `device.isFirstAppOpen` property that you can use in paywall rules. This is `true` for the very first time a user opens the app. When the user closes and reopens the app, this will be `false`.
- Removes the need to tell us when you're going to present/have presented a `PaywallViewController` that has been retrieved using `getPaywallViewController(...)`.
- Adds `isInspectable` to the paywall web view if running on iOS 16.4+.
- Exposes `PaywallViewControllerDelegate` to be used with `getPaywallViewController(...)`

### Fixes

- Fixes various memory related crashes.
- Fixes a crash when calling `reset()` when a paywall is displayed.

## 3.0.0-rc.5

### Fixes

- Fixes bug where `Superwall.shared.register`'s feature handler would not be called if the user is subscribed.

## 3.0.0-rc.4

### Breaking Changes

- Changes `DismissState` to `PaywallResult`.
- Removes the `closedForNextPaywall` case from `PaywallResult` in favor of a new `PaywallInfo` property called `closeReason`, which can either be `nil`, `.systemLogic`, or `.forNextPaywall`.
- Changes the `PaywallPresentationHandler` variables to functions.
- Removes `Superwall.shared.track`. We're going all in on `Superwall.shared.register` baby!
- Removes .error(Error) from `PaywallSkippedReason` in favor of a new `PaywallState` case `.presentationError(Error)`. 
- Removes `PaywallPresentationHandler` completion block variables removed in favor of function calls with the same names. 
- Changes `.onError` of `PaywallPresentationHandler` to no longer be called when a paywall is intentionally not shown (i.e. user is subscribed, user is in holdout, no rule match, event not configured)
- Adds `.onSkip(reason:)` to `PaywallPresentationHandler` to handle cases where paywall isn't shown because user is subscribed, user is in holdout, no rules match, event not configured

### Enhancements

- Adds `getPaywallViewController`! You can no request an actual view controller to present however you like. Check function documentation in Xcode for instructions – follow directions closely.  
- Changes default logging level to `INFO`.
- Adds new automatically tracked `paywall_decline` event that can be used to present a new paywall when a user dismisses a paywall.
- Allows `transaction_abandon` to trigger new paywalls when added to a campaign – called when a user abandons checkout (did you know 75% of the time, users abandon checkout when Apple's payment sheet comes up?!).
- Adds `.onSkip` to `PaywallPresentationHandler` which is passed a `PaywallSkippedReason` when a paywall is not supposed to show.
- Adds logging at `INFO` level, mansplaining exactly why a paywall is not shown when calling `register` or `getPaywallViewController`.
- Adds new automatically tracked event `presentation_request` that gets sent with properties explaining why a paywall was or was not shown. 

### Fixes

- Paywalls will now show even if you are missing products.

## 3.0.0-rc.3

### Breaking Changes

- Changes the `logLevel` to be non-optional and introduces a `none` case to turn off logging.
- Removes all guides from the SDK documentation. From now on, our [online docs](https://docs.superwall.com/docs/) provide guides and the SDK documentation is only there as a technical reference.
- Changes `TrackResultObjc` to `PresentationResultObjc`
- Removes convenience methods for creating PaywallPresentationHandlers because they were a bit confusing
- Changes the return type of `PurchaseController.restorePurchases()` from `bool` to `RestorationResult`

### Enhancements

- If you're using SwiftUI, you can now call `Superwall.configure` in the `init()` of your `App` file. This means you don't need to have a `UIApplicationDelegate`.
- Prevents validation of restorations and purchases if you're using a `PurchaseController` - it's now all on you!
- Updates Objective-C sample app to use `Superwall.register` and removes legacy StoreKit code.
- Simplifies SwiftUI and RevenueCat example app.
- You can now access `device.subscriptionStatus` in a rule, which is a string that's either `ACTIVE`, `INACTIVE`, or `UNKNOWN`.
- You no longer need to have swiftlint installed to run our example apps.
- If you're not using a `PurchaseController` and a user comes across the "You're already subscribed to this product" popup, we will now correctly identify this as a restoration and not a purchase. This can happen when testing in sandbox if you purchase a product -> delete and reinstall the app -> open a paywall and purchase.
- Adds static variable `Superwall.isInitialized` which is `true` when initialization is complete and `Superwall.shared` can be accessed.
- Adds `transaction_abandon` and `transaction_fail` as potential triggers. This comes with a new `DismissState` case `closedForNextPaywall`, which is returned when dismissing one paywall for another.

### Fixes

- Fixes issue where an invalid URL provided for an "Open URL" click behavior would result in a crash.
- Exposes `PaywallPresentationHandler` as `SWKPaywallPresentationHandler` for Objective-C.

## 3.0.0-rc.2

### Enhancements

- Simplifies Superwall-UIKit-Swift example project.

### Fixes

- Fixes bug where calling Superwall.shared prior to Superwall.configure would result in a recursive loop .

## 3.0.0-rc.1

### Breaking Changes

- Adds `PaywallInfo` to `SuperwallDelegate` methods `paywallWillPresent(withInfo:)`, `paywallDidPresent(withInfo:)`, `paywallWillDismiss(withInfo:)` and `paywallDidDismiss(withInfo:)`.
- Renames `SuperwallDelegate` method `didTrackSuperwallEventInfo(_:SuperwallEventInfo)` to `handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo)` for clarity
- Renames `SuperwallDelegate` methods `willOpenURL(url:)` and `willOpenDeepLink(url:)` to `paywallWillOpenURL(url:)` and `paywallWillOpenDeepLink(url:)` respectively
- Decouples associated value of `.dismissed` in `Superwall.shared.track()` closure to `PaywallInfo` and `DismissState`.
- Changes `subscription_status_did_change` to `subscriptionStatus_didChange`.
- Renames `TrackResult` to `PresentationResult`

### Enhancements

- Introducing `Superwall.shared.register(event:params:handler:feature)`, Superwall's most powerful feature yet. Wrap your features with this method to conditionally show paywalls, lock features and more.
- Adds a drawer display option which displays the paywall at 70% screen height on iOS 16 iPhones.
- Adds warning if setting subscription status without passing through a PurchaseController during config.
- Adds `$is_feature_gatable` standard property to register and track calls
- Cleans up and reformats SDK logs

### Fixes

- Fixes a long term bug where tracking an event to show a paywall and tracking an event that results in noRuleMatch would interfere with each other and cause the trigger session to be set to `nil`. This resulted in some paywall data being incorrect on the dashboard.

## 3.0.0-beta.8

### Enhancements

- Prevents the tracking of events that have the same name as internally tracked `SuperwallEvents` like `paywall_open`.

### Fixes

- Fixes an issue with reporting in the dashboard due to a mismatch of keys between client and server.

## 3.0.0-beta.7

### Breaking Changes

- Changes Objective-C method `getTrackInfo` to `getTrackResult` to be in line with the Swift API.
- Removes the error case from the `TrackResult` and adds in `userIsSubscribed` and `paywallNotAvailable` cases.
- Moves main actor conformance to functions of PurchaseController protocol rather than the whole protocol.
- Changes Objective-C method `setUserAttributesDictionary(_:)` to `setUserAttributes(_:)`.

### Fixes

- Makes `NetworkEnvironment` Objective-C compatible.
- Fixes an issue where a manually dismissed modally presented paywall wouldn't properly dismiss.
- Fixes race condition when calling identify and tracking a paywall.

## 3.0.0-beta.6

### Breaking Changes

- `identify(userId:)` is not longer a throwing async function. Any error that occurs is logged.
- `reset` is no longer an async function.
- `presentedViewController` and `latestPaywallInfo` no longer restricted to the main actor.
- Removes `localizationOverride(localeIdentifier:)` and replaces it with the `SuperwallOption` `localeIdentifier`. You set this on configure.
- Removes delegate from `configure`. You now set the delegate via `Superwall.shared.delegate`.
- Removes `presenter` introduced in beta 5.
- Removes ASN1Swift as a package dependency.
- Changes free trial logic. Previously we'd look at just the primary product. However, we determing free trial eligibility based on the first product in the paywall that has a free trial available.

### Enhancements

- You can now target `device.isSandbox` in rules.

### Fixes

- Fixes bug where calling identify and immediately tracking a paywall would result in an error if it happened before configure returned.
- Fixes compiler bug when calling track.
- Tweaks the loading indicator.
- Fixes removing an attribute using Objective-C.
- Fixes issues where some functions tagged for the main actor weren't actually running on the main actor.
- Fixes issues with paywall product overrides.

## 3.0.0-beta.5

### Breaking Changes

- Changes `SubscriptionController` to `PurchaseController`. You now set this in `Superwall.shared.configure`, rather than via the delegate.
- Removes `isUserSubscribed()` from the `SuperwallDelegate` and replaces this with a published instance variable `subscriptionStatus`. This is enum that defaults to `.unknown` on first install and the cached value on subsequent app opens. If you're using a `SubscriptionController` to handle subscription-related logic, you must set `subscriptionStatus` every time the user's subscription status changes. If you're letting Superwall handle subscription-related logic, this value will be updated with the device receipt.
- `hasActiveSubscriptionDidChange(to:)` is replaced in favour of `subscriptionStatusDidChange(to:)`.
- Makes `Superwall.shared.options` internal so that options must be set in `configure`.

### Enhancements

- Adds a new event `SubscriptionStatusDidChange` which is logged on the dashboard.
- Adds an optional `presenter` parameter to `track`. In v2 this was known as `on`. This takes a `UIViewController` which is used to present the paywall.

## 3.0.0-beta.4

### Breaking Changes

- Moves back to using `Superwall.shared.identify(userId: userId)` and `reset()` instead of logIn/createAccount/logout/reset. This is so that it's easier for integration. However, you can now pass an `IdentityOptions` object to `identify(userId:options)`. This should only be used in advanced use cases. By setting the `restorePaywallAssignments` property of `IdentityOptions` to `true`, it prevents paywalls from showing until after paywall assignments have been restored. If you expect users of your app to switch accounts or delete/reinstall a lot, you'd set this when identifying an existing account.

### Enhancements

- Adds `hasActiveSubscriptionDidChange(to:)` delegate function. If you're letting Superwall handle subscription logic you can use this to receive a callback whenever the user's internal subscription status changes. You can also listen to the published `hasActiveSubscription` variable.
- Adds a completion handler to `Superwall.configure(...)` that lets you know when Superwall has finished configuring. You can also listen to the published `isConfigured` variable.
- If you let Superwall handle your subscription-related logic, we now assume that a non-consumable product on your paywall is a lifetime subscription. If not, you'll need to return a `SubscriptionController` from the delegate.
- `handleDeepLink(_:)` now returns a discardable `Bool` indicating whether the deep link was handled. If you're using `application(_:open:options:)` you can return its value there.
- Adds `togglePaywallSpinner(isHidden:)` to arbitrarily toggle the loading spinner on and off. This is particularly useful when you're doing async work when performing a custom action in `handleCustomPaywallAction(withName:)`.

### Fixes

- Fixes occasional thread safety related crash when loading products.
- Reverts a issue from the last beta where the paywall spinner would move up before the payment sheet appeared.

## 3.0.0-beta.3

### Fixes

- Fixes potential crash due to a using a lazy variable.

## 3.0.0-beta.2

### Breaking Changes

- Moves all functions and variables to the `shared` instance for consistency, e.g. it's now `Superwall.shared.track()` instead of `Superwall.track()`.

### Enhancements

- Readds `Superwall.shared.logLevel` as a top level static convenience variable so you can easily change the log level.
- Adds `isLoggedIn` to user properties, which means you can create a rule based on whether the user is logged in vs. whether they're anonymous.

### Fixes

- Fixes bug in `<iOS 14` where the spinner wasn't appearing when transacting.
- Fixes bug where PaywallOverrides weren't being passed in to the paywall.
- Fixes bug where purchasing, deleting then reinstalling your app, and tapping a purchase button would throw an error.
- Fixes an rare crash associated with the loading and saving of Core Data.

## 3.0.0-beta.1

Welcome to `SuperwallKit` v3.0, the framework formally known as `Paywall`!

This update is a major release, containing lots of breaking changes, enhancements and some bug fixes. We're excited for you to use it!

We understand that transitions between major SDK releases can become frustrating, so we've made a [migration guide](https://docs.superwall.com/v3.0/docs/migrating-to-v3) to make your life easier. We've also updated out [sample apps](Examples) to v3, including RevenueCat+SuperwallKit and Objective-C apps. For new users, we've created a [Quick Start Guide](https://docs.superwall.com/v3.0/docs/quick-start) to get up and running in no time. Finally, we recommend you check out our [updated docs](https://docs.superwall.com/docs).

### Breaking Changes

- Renames the package from `Paywall` to `SuperwallKit`.
- Renames the primary static class for integrating Superwall from `Paywall` to `Superwall`.
- Sets the minimum iOS version to iOS 13.
- Renames `preloadPaywalls(forTriggers:)` to `preloadPaywalls(forEvents:)`
- Renames `configure(apiKey:userId:delegate:options:)` to `configure(apiKey:delegate:options:)`. This means you no longer provide a `userId` with configure. Instead you must use the new identity API detailed below.
- Changes `PaywallOptions` to `SuperwallOptions`. This now clearly defines which of the options are explicit to paywalls vs other configuration options within the SDK.
- Renames `Superwall.trigger(event:)` to `Superwall.track(event:)`. We found that having separate implicit (`Superwall.track(event:)`) and explicit (`Superwall.trigger(event:)`) trigger functions caused confusion. So from now on, you'll just use `Superwall.track(event:)` for all events within your app.
- Renames `Paywall.EventName` to `SuperwallEvent` and removes `.manualPresent` as a `SuperwallEvent`.
- Renames `PaywallDelegate` to `SuperwallDelegate`.
- Superwall automatically handles all subscription-related logic, meaning that it's no longer a requirement to implement any of the delegate methods. Note that if you're using RevenueCat, you will still need to use the delegate methods. This is because the Superwall-handled subscription status is App Store account-specific, whereas RevenueCat is logged in user-specific. If this isn't a problem, you can just set RevenueCat in observer mode and we'll take care of the rest :)
- Moves purchasing logic from the delegate into a protocol called `SubscriptionController`. You return your `SubscriptionController` from the delegate method `subscriptionController()`.
- For Swift users, this changes the `SubscriptionController` method `purchase(product:)` to an async function that returns a `PurchaseResult`. Here, you need to return the result of the user attempting to purchase a product, making sure you handle all cases of `PurchaseResult`: `.purchased`, `.cancelled`, `.pending`, `failed(Error)`.
- For Objective-C users, this changes the delegate method `purchase(product:)` to `purchase(product:completion:)`. You call the completion block with the result of the user attempting to purchase a product, making sure you handle all cases of `PurchaseResultObjc`: `.purchased`, `.cancelled`, `.pending`, `failed`. When you have a purchasing error, you need to call the completion block with the `.failed` case along with the error.
- Changes `restorePurchases()` to an async function that returns a boolean instead of having a completion block.
- Removes `identify(userId:)` in favor of the new Identity API detailed below.
- Removes `Paywall.load(identifier:)`. This was being used to preload a paywall by identifier.
- Removes `.triggerPaywall()` for SwiftUI apps. Instead, SwiftUI users should now use the UIKit function `Superwall.track()`. Take a look at our SwiftUI example app to see how that works.
- Changes the `period` and `periodly` attributes for 2, 3 and 6 month products. Previously, the `period` would be "month", and the `periodly` would be "monthly" for all three. Now the `period` returns "2 months", "quarter", "6 months" and the `periodly` returns "every 2 months", "quarterly", and "every 6 months".

### Enhancements

- New identity API:
  - `logIn(userId:)`: Logs in a user with their `userId` to retrieve paywalls that they've been assigned to.
  - `createAccount(userId:)`: Creates an account with Superwall. This links a `userId` to Superwall's automatically generated alias.
  - `logOut(userId:)`: Logs out the user, which resets on-device paywall assignments and the `userId` stored by Superwall.
  - `reset()`: Resets the `userId`, on-device paywall assignments, and data stored by Superwall. This can be called even if the user isn't logged in.
- The identity API can be accessed using async/await or completion handlers.
- New function `Superwall.publisher(forEvent:params:overrides)` which returns a `PaywallStatePublisher` (`AnyPublisher<PaywallState, Never>`) for those Combine lovers. By subscribing to this publisher, you can receive state updates of your paywall. We've updated our sample apps to show you how to use that.
- Adds `Superwall.isLoggedIn` to check whether the user is logged in to the SDK or not. This will be true if you've previously called `logIn(userId:)` or `createAccount(userId:)`.
- Adds a new example app, UIKit+RevenueCat, which shows you how to use Superwall with RevenueCat.
- Adds a new Objective-C example app UIKit-Objc.
- Adds an Objective-C-only function `removeUserAttributes(_:)` to remove user attributes. In Swift, to remove attributes you can pass in `nil` for a specific attribute in `setUserAttributes(_:)`.
- Adds `getTrackResult(forEvent:params:)`. This returns a `TrackResult` which tells you the result of tracking an event, without actually tracking it. This is useful if you want to figure out whether a paywall will show in the future.
- Logs when products fail to load with a link to help diagnose the cause.
- Adds a published property `hasActiveSubscription`, which you can check to determine whether Superwall detects an active subscription. Its value is stored on disk and synced with the active purchases on device. If you're using Combine or SwiftUI, you can subscribe or bind to this to get notified whenever the user's subscription status changes. If you're implementing your own `SubscriptionController`, you should rely on your own logic to determine subscription status.
- Adds a published property `isConfigured`. This is a boolean which you can use to check whether Superwall is configured and ready to present paywalls.
- Adds `isFreeTrialAvailable` to `PaywallInfo`.
- Tracks whenever the paywall isn't presented for easier debugging.

### Fixes

- Fixes a caching issue where the paywall was still showing in free trial mode when it shouldn't have. This was happening if you had purchased a free trial, let it expire, then reopened the paywall. Note that in Sandbox environments this issue may still occur due to introductory offers not being added to a receipt until after a purchase.
- The API uses background threads wherever possible, dispatching to the main thread only when necessary and when returning from completion blocks.
- The API is now fully compatible with Objective-C.
- Setting the `PaywallOption` `automaticallyDismiss` to `false` now keeps the loading indicator visible after restoring and successfully purchasing until you manually dismiss the paywall.
- Improves the speed of requests by changing the cache policy of requests to our servers.
- Fixes `session_start`, `app_launch` and `first_seen` not being tracked if the SDK was initialised a few seconds after app launch.
- Stops the unnecessary retemplating of paywall variables when coming back to the paywall after visiting a link via the in-app browser.
- Removes the transaction timeout popup. This was causing a raft of issues so we now rely on overlayTimeout to cancel the transaction flow.

---

## 2.5.8

### Enhancements

- Adds `isExternalDataCollectionEnabled` data privacy `PaywallOption`. When `false`, prevents non-Superwall events and properties from being sent back to the superwall servers.
- Adds an `X-Is-Sandbox` header to all requests such that sandbox data doesn't affect your production analytics on superwall.com.

### Fixes

- Fixes a bug that prevented the correct calculation of a new app session.
- Fixes missing loading times of the webview and products.

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
- Previously calls to `Paywall.preloadPaywalls(forTriggers:)` before `Paywall.config()` finished were ignored. This has been fixed.
- If a user had already bought a product within a subscription group, they were still being offered a free trial on other products within that group. This is incorrect logic and this update fixes that.
- # Fixed a bug where `Paywall.reset()` couldn't be called on a background thread.
- Previously, calling `Paywall.preloadPaywalls(forTriggers:)` before `Paywall.config()` finished would not work. This has been fixed.
- Previously, if a user purchases a product within a subscription group, they would still be offered a free trial on other products within that group. This has been fixed.
- Fixes a bug where `Paywall.reset()` couldn't be called on a background thread.

---

## 2.4.1

### Enhancements

- Adds `Paywall.preloadAllPaywalls()` and `Paywall.preloadPaywalls(forTriggers:)`. Use this with `Superwall.options.shouldPreloadPaywall = false` to have more control over when/what paywalls are preloaded.

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
- Deprecates old `track` functions. The only one you should use is `Superwall.track(_:_:)`, to which you pass an event name and a dictionary of parameters. Note: This is not backwards compatible with previous versions of the SDK.
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
