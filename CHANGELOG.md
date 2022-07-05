# CHANGELOG

The changelog for `Paywall`. Also see the [releases](https://github.com/superwall-me/paywall-ios/releases) on GitHub.

2.4.0 (upcoming release)
-----

### Enhancements
- New _push_ presentation style. By selecting Push on the superwall dashboard, your paywall will push and pop in as if it's being pushed/popped from a navigation controller. If you are using UIKit, you can provide a view controller to `Paywall.trigger` like this: `Paywall.trigger(event: "MyEvent", on: self)`. This will make the push transition more realistic, by moving its view in the transition. Note: This is not backwards compatible with previous versions of the SDK.
- New _no animation_ presentation style. By selecting No Animation in the superwall dashboard, you can disable presentation/dismissal animation. This release deprecates `Paywall.shouldAnimatePaywallDismissal` and `Paywall.shouldAnimatePaywallPresentation`.
- New dedicated function for handling deeplinks: `Paywall.handleDeepLink(url)`
- New `Paywall.shouldPreloadPaywalls` flag. Set this to `false` to make paywalls load and cache in a just-in-time fashion. This deprecates the old `Paywall.shouldPreloadTriggers` flag.
- Deprecates old `track` functions. The only one you should use is `Paywall.track(_:_:)`, to which you pass an event name and a dictionary of parameters. Note: This is not backwards compatible with previous versions of the SDK.
- Adds a new way of internally tracking analytics associated with a paywall and the app session. This will greatly improve the Superwall dashboard analytics.
- Adds support for javascript expressions defined in rules on the Superwall dashboard.
- Updates the SDK documentation.
- Adds `trialPeriodEndDate` as a product variable. This means you can tell your users when their trial period will end, e.g. `Start your trial today — you won't be billed until {{primary.trialPeriodEndDate}}` will print out `Start your trial today — you won't be billed until June 21, 2023`.
- Exposes `Paywall.presentedViewController`. This gives you access to the `UIViewController` of the paywall incase you need to present a view controller on top of it.
- Adds `today`, `daysSinceInstall`, `minutesSinceInstall`, `daysSinceLastPaywallView`, `minutesSinceLastPaywallView` and `totalPaywallViews` as `device` parameters. These can be references in your rules and paywalls with `{{ device.paramName }}`.

### Fixes
- Adds the missing Superwall events `app_install`, `paywallWebviewLoad_fail` and `nonRecurringProduct_purchase`.
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
- Deprecates `Paywall.debugMode`. All logs are now controlled by setting `Paywall.logLevel`. The default `logLevel` is now `.warn`.

2.3.0
-----

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
