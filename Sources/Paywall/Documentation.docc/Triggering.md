# Triggering a Paywall

Show a paywall in your app in response to an analytical event.

## Overview

Triggers enable you to retroactively decide where and when to show a paywall in your app.

A trigger is an analytics event you can wire up to specific rules in a Campaign on the [Superwall Dashboard](https://superwall.com/dashboard). The Paywall SDK listens for these analytics events and evaluates their rules to determine whether or not to show a paywall when the trigger is fired.

Paywalls are **sticky**, in that when a user is assigned a paywall within a rule, they will continue to see that paywall unless you remove the paywall from the rule.

You can attach a trigger to your own analytical events that you send or you can attach a trigger to some of the [automatically tracked events](<doc:AutomaticallyTrackedEvents>). Specifically: `app_install`, `app_launch`, and `session_start`.

## Triggering a Paywall

When you sign up for a Superwall account, we give you an example paywall and campaign to test your integration. The example campaign contains a trigger event called `campaign_trigger`, which you'll fire in your app when you want to show the paywall. There are two ways to do this via the SDK: **explicitly** and **implicitly**:

### Explicit Triggers in UIKit

If you're using UIKit and you need completion handlers for a trigger, you need to use an explicit trigger by calling ``Paywall/Paywall/trigger(event:params:on:products:ignoreSubscriptionStatus:presentationStyleOverride:onSkip:onPresent:onDismiss:)``:

```swift
Paywall.trigger(
  event: "campaign_trigger",
  onSkip: { error in }, 
  onPresent: { paywallInfo in }, 
  onDismiss: { didPurchase, productId, paywallInfo in }
)
```

In this example, you're sending the event `campaign_trigger` to the dashboard. If you wanted you could also send some parameters, which can be referred to in the rules you define in your campaign. You can then utilize the completion handlers associated with the paywall presentation state.

> `onSkip` is a completion block that gets called when the paywall's presentation is skipped. This accepts an `NSError?` with more details. It is recommended to check the error code to handle the onSkip callback. If the error code is `4000`, it means the user didn't match any rules. If the error code is `4001` it means the user is in a holdout group. Otherwise, a `404` error code means an error occurred.

### Explicit Triggers in SwiftUI

If you're using SwiftUI and need completion handlers for a trigger, you need to use an explicit trigger by attaching the view modifier `.triggerPaywall(forEvent:withParams:shouldPresent:presentationStyleOverride:onPresent:onDismiss:onFail:)` to a view.

The example below triggers a paywall when the user toggles the `showPaywall` variable by tapping on the **Trigger Paywall** button. The paywall will only show if the trigger for the `campaign_trigger` event is active in the [Superwall Dashboard](https://superwall.com/dashboard) and the user doesn't have an active subscription:

```swift
struct ContentView: View {
  @State private var showPaywall = false

  var body: some View {
    Button(
      action: {
        showPaywall.toggle()
      },
      label: {
        Text("Trigger Paywall")
      }
    )
    .triggerPaywall(
      forEvent: "campaign_trigger",
      shouldPresent: $showPaywall,
      onPresent: { paywallInfo in
        print("paywall info is", paywallInfo)
      },
      onDismiss: { result in
        switch result.state {
        case .closed:
          print("User dismissed the paywall.")
        case .purchased(productId: let productId):
          print("Purchased a product with id \(productId), then dismissed.")
        case .restored:
          print("Restored purchases, then dismissed.")
        }
      },
      onFail: { error in
        print("did fail", error)
      }
    )
  }
}
```

> `onFail` is a completion block that gets called when the paywall's presentation fails. This accepts an `NSError?` with more details. It is recommended to check the error code to handle the onFail callback. If the error code is `4000`, it means the user didn't match any rules. If the error code is `4001` it means the user is in a holdout group. Otherwise, a `404` error code means an error occurred.

### Implicit Triggers

```swift
Paywall.track("campaign_trigger")
```

To provide your team with ultimate flexibility, we recommend sending all your analytical events to Superwall via ``Paywall/Paywall/track(_:_:)-2vkwo``. That way you can retroactively add a paywall to any of your analytical events, should you decide to do so.

## Integrating with Existing Analytics

If you're already set up with an analytics provider, you'll typically have an `Analytics.swift` singleton (or similar) to disperse all your events from. Here's how that file might look:

```swift
import Paywall
import Mixpanel
import Firebase

final class Analytics {
  static let shared = Analytics()
  
  func track(
    event: String,
    properties: [String: Any]
  ) {
    // Superwall
    Paywall.track(event, properties)
    
    // Firebase (just an example)
    Firebase.Analytics.logEvent(event, parameters: properties)
    
    // Mixpanel (just an example)
    Mixpanel.mainInstance().track(event: eventName, properties: properties)
  }
}
```

Therefore you can track all your analytics in one go. For example:
  
```swift
Analytics.shared.track(
  "workout_complete",
  ["total_workouts": 17]
)
```

### Using Your Own Paywalls

Now that you've triggered the example paywall, it's time to set up your own paywall. First you'll need to [build your paywall](https://docs.superwall.com/docs/overview). Next, you need to [configure your paywall](https://docs.superwall.com/docs/configuring-a-paywall) and [create a campaign](https://docs.superwall.com/docs/campaigns). You can then use this in your app in the same way as you did above!
