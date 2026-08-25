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

A pushed Customer Center shows a back button instead of a close button, and hides your navigation
bar for as long as it is on screen. It supplies its own navigation bar in place of yours, because
its drill-downs — purchase history and per-purchase detail — need a SwiftUI navigation stack that
a `UINavigationController` can't provide. Your bar is restored exactly as it was found when the
user leaves, and swipe-to-go-back keeps working throughout.

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
