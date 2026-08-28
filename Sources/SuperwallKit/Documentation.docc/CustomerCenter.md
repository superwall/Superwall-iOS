# Customer Center

A native, self-service screen where users can view and manage their subscriptions and purchases.

## Overview

The Customer Center lets users restore purchases, manage or cancel a subscription, request a
refund, change plans, contact support, answer exit surveys and browse purchase history — all
without leaving your app. It ships with sensible defaults and is fully configurable, so you can
tailor which paths appear, their titles, surveys and appearance to match your app.

The Customer Center requires **iOS 15.0+**.

### Presenting from UIKit

Present it over your current view controller with ``Superwall/presentCustomerCenter(configuration:from:delegate:onDismiss:)``:

```swift
Superwall.shared.presentCustomerCenter()
```

Or use ``CustomerCenterViewController`` yourself. Present it modally:

```swift
let customerCenter = CustomerCenterViewController(delegate: myDelegate)
present(customerCenter, animated: true)
```

Or push it onto a navigation controller of your own, which is what you want when the Customer
Center is a row in your own settings screen:

```swift
let customerCenter = CustomerCenterViewController(
  presentationStyle: .pushed,
  delegate: myDelegate
)
navigationController?.pushViewController(customerCenter, animated: true)
```

A pushed Customer Center renders into your navigation bar and leaves it alone — your title, your
back button, your appearance, your swipe-to-go-back. It adds no close button, since your stack
already provides the way back. Its own screens, purchase history and per-purchase detail, are
pushed onto your stack as further view controllers, so they behave like any other screen you
pushed yourself.

> Important: A `CustomerCenterViewController` you construct yourself is yours, and the SDK does not
> track it. ``Superwall/presentCustomerCenter(configuration:from:delegate:onDismiss:)`` will present
> a second, independent Customer Center over the top of one you pushed, and
> ``Superwall/dismissCustomerCenter(completion:)`` only dismisses the one the SDK presented — it
> does nothing to yours. Pick one entry point per screen: let the SDK present it, or own the
> lifecycle of the controller you construct.

### Presenting from SwiftUI

Use the ``SwiftUICore/View/presentSuperwallCustomerCenter(isPresented:configuration:onDismiss:)`` modifier to present it as a sheet:

```swift
struct SettingsView: View {
  @State private var showsCustomerCenter = false

  var body: some View {
    Button("Manage Subscription") {
      showsCustomerCenter = true
    }
    .presentSuperwallCustomerCenter(isPresented: $showsCustomerCenter)
  }
}
```

Or embed ``CustomerCenterView`` directly in your own navigation stack:

```swift
CustomerCenterView(navigationOptions: .init(usesExistingNavigation: true))
```

### Presenting from Objective-C

Use `presentCustomerCenterWithConfiguration:from:delegate:onDismiss:`:

```objc
[Superwall.sharedInstance presentCustomerCenterWithConfiguration:nil
                                                              from:nil
                                                          delegate:myDelegate
                                                         onDismiss:nil];
```

## Configuring the Customer Center

Set the default configuration via ``SuperwallOptions/customerCenter`` before calling
`Superwall.configure(apiKey:purchaseController:options:completion:)`, or pass a
``CustomerCenterConfiguration`` directly to a presentation call to override it for that
presentation only.

```swift
let options = SuperwallOptions()

let cancelSurvey = CustomerCenterConfiguration.FeedbackSurvey(
  id: "cancel_survey",
  title: "Why are you cancelling?",
  options: [
    .init(id: "too_expensive", title: "Too expensive"),
    .init(id: "dont_use", title: "Don't use it enough"),
    .init(id: "bought_by_mistake", title: "Bought by mistake")
  ]
)

options.customerCenter = CustomerCenterConfiguration(
  managementScreen: .init(
    paths: [
      .init(id: "restore", type: .restore),
      .init(id: "change_plan", type: .changePlan()),
      .init(id: "refund", type: .refund()),
      .init(id: "manage_subscription", type: .manageSubscription, survey: cancelSurvey),
      .init(id: "faq", type: .url(URL(string: "https://mycompany.com/faq")!, openMethod: .inApp)),
      .init(id: "contact_support", type: .contactSupport)
    ]
  ),
  noPurchasesScreen: .init(
    paths: [.init(id: "restore", type: .restore)]
  ),
  support: .init(email: "support@mycompany.com")
)

Superwall.configure(apiKey: "MY_API_KEY", options: options)
```

Every path is optional and reorderable. Built-in path types (``CustomerCenterConfiguration/PathType``)
cover restoring purchases, managing or cancelling a subscription, requesting a refund, changing
plans, and contacting support; ``CustomerCenterConfiguration/PathType/url(_:openMethod:)`` opens a
URL either in-app or externally, and ``CustomerCenterConfiguration/PathType/custom(identifier:)``
lets you handle an action entirely yourself via the delegate.

### Warning customers about old versions

The Customer Center can show a banner asking the customer to update. By default it finds the
published version itself, by looking your app up on the App Store:

```swift
options.customerCenter.support = .init(
  email: "support@mycompany.com",
  shouldWarnToUpdate: true          // on by default
)
```

Set `latestAppVersion` to skip the lookup and warn against a version you control, which is what
you want if you gate support on a specific build:

```swift
options.customerCenter.support = .init(
  email: "support@mycompany.com",
  latestAppVersion: "2.1.0"
)
```

The banner appears only when the installed version is *older* than the published one — never when
it merely differs. It is skipped entirely on TestFlight, sandbox and simulator builds, whose
version is normally ahead of the App Store. Set `checksAppStoreForUpdates` to `false` to stop the
lookup without turning the banner off. Any failure — offline, no listing found, an unparseable
version — hides the banner and logs under the `customerCenter` scope.

> Note: The lookup result is cached for 24 hours, and only the bundle identifier is sent. Because
> it happens after the screen has loaded, the banner animates in a moment later rather than being
> there on first paint.

> Warning: Apple phases a release in over seven days, but the lookup sees the new version as soon
> as it goes live. For the first few days of a release, some customers are told to update to a
> build that hasn't reached them yet. If that matters for your app, set `latestAppVersion` and
> raise it on your own schedule, or set `checksAppStoreForUpdates` to `false`.

## The Delegate

Implement ``CustomerCenterDelegate`` (or ``CustomerCenterDelegateObjc`` from Objective-C) to
observe and, where relevant, gate what happens in the Customer Center:

```swift
final class MyCustomerCenterDelegate: CustomerCenterDelegate {
  func customerCenter(shouldRestorePurchases resume: @escaping (Bool) -> Void) {
    resume(true)
  }

  func customerCenter(didSelect action: CustomerCenterAction, for purchase: SubscriptionTransaction?) {
    print("Customer Center action selected: \(action)")
  }

  func customerCenter(didCompleteSurvey surveyId: String, optionId: String, for action: CustomerCenterAction) {
    print("Survey \(surveyId) answered with \(optionId)")
  }

  func customerCenter(didCompleteRefundRequestFor productId: String, status: CustomerCenterRefundStatus) {
    print("Refund request for \(productId) finished with status \(status)")
  }

  func customerCenterDidDismiss() {
    print("Customer Center dismissed")
  }
}
```

The view controller does not retain its delegate — either keep a strong reference to it yourself,
or pass it to `presentCustomerCenter(delegate:)`, which retains it for the duration of the
presentation.

In SwiftUI, use the equivalent modifiers instead of a delegate:

```swift
CustomerCenterView()
  .onCustomerCenterShouldRestore { resume in resume(true) }
  .onCustomerCenterAction { action, purchase in print(action) }
  .onCustomerCenterSurveyResponse { surveyId, optionId, action in print(surveyId, optionId) }
  .onCustomerCenterRefundRequest { productId, status in print(productId, status) }
  .onCustomerCenterDismiss { print("dismissed") }
```

## Events

The Customer Center fires the following ``SuperwallEvent`` cases, which you can observe via
``SuperwallDelegate/handleSuperwallEvent(withInfo:)`` alongside all other SDK events:

- `customerCenterOpen`: the Customer Center is presented.
- `customerCenterClose`: the Customer Center is dismissed.
- `customerCenterAction`: the user taps a path.
- `customerCenterSurveyResponse`: the user answers a survey attached to a path.
- `customerCenterRefundRequest`: a refund request finishes.

## Limitations

- Requires iOS 15.0+. On earlier versions, presentation calls are unavailable at compile time.
- Promotional offers are not yet supported as a Customer Center path.
- Remote configuration of the Customer Center from the Superwall dashboard is coming; today it's
  configured entirely in code via ``SuperwallOptions/customerCenter``.
