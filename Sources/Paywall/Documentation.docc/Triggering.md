# Triggering a Paywall

Show a specific paywall in your app in response to an analytical event.

## Overview

Triggers enable you to retroactively decide where and when to show a specific paywall in your app.

You configure a trigger via the dashboard, specifying which paywall will show in response to an analytical event sent via the SDK.

You can attach a trigger to your own analytical events that you send with ``Paywall/Paywall/track(_:_:)-2vkwo``, or you can attach a trigger to some of the [automatically tracked events](<doc:AutomaticallyTrackedEvents>). Specifically: `app_install`, `app_launch`, and `session_start`.

The SDK recognizes when it is sending an event that's tied to an active trigger in the dashboard and will display the corresponding paywall.

> Important: Triggered paywalls are  **not sticky**. The paywall shown to the user is determined by the trigger associated with the event in the dashboard. This means that if the trigger is turned off, the user will no longer see it.


## Configuring a Trigger on the Dashboard

First, you'll need to configure your trigger on the [Superwall Dashboard](https://superwall.com/dashboard).

On the dashboard, go to the **Triggers** section and click the **+ button** to create a new trigger:

![Adding a Trigger on the Superwall Dashboard](addATrigger.png)

Select a **paywall**, type a new **event name** or select one from the drop down, then click **Create**:

![Configuring a Trigger on the Superwall Dashboard](configureTrigger.png)

Then, enable the trigger:

![Enabling a Trigger on the Superwall Dashboard](enableTrigger.png)

Your trigger is now enabled! The above example shows the paywall **Test** when the SDK sends an event named `workout_complete`.

## Triggering a Paywall via the SDK

Once you have your trigger configured in the dashboard, you need send its event from your app.
There are two ways to do this via the SDK: **explicitly** and **implicitly**:

### Explicit Triggers in SwiftUI

If you're using SwiftUI and need completion handlers for a trigger, you need to use an explicit trigger by attaching the view modifier `.triggerPaywall(forEvent:withParams:shouldPresent:onPresent:onDismiss:onFail:)` to a view.

The example below triggers a paywall when the user toggles the `showPaywall` variable by tapping on the **Complete Workout** button. The paywall will only show if the trigger for the `workout_complete` event is active in the [Superwall Dashboard](https://superwall.com/dashboard) and the user doesn't have an active subscription:

```swift
struct ContentView: View {
  @State private var showPaywall = false

  var body: some View {
    Button(
      action: {
        showPaywall.toggle()
      },
      label: {
        Text("Complete Workout")
      }
    )
    .triggerPaywall(
      forEvent: "workout_complete",
      withParams: ["total_workouts": 17],
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

### Explicit Triggers in UIKit

If you're using UIKit and you need completion handlers for a trigger, you need to use an explicit trigger by calling ``Paywall/Paywall/trigger(event:params:on:ignoreSubscriptionStatus:onSkip:onPresent:onDismiss:)``:

```swift
Paywall.trigger(
  event: "workout_complete", 
  params: ["total_workouts": 17], 
  onSkip: { error in }, 
  onPresent: { paywallInfo in }, 
  onDismiss: { didPurchase, productId, paywallInfo in }
)
```

In this example, you're sending the event `workout_complete` to the dashboard along with some parameters. You can then utilize the completion handlers associated with the paywall presentation state.

### Implicit Triggers

```swift
Paywall.track(
  "workout_complete", 
  ["total_workouts": 17]
)
```

To provide your team with ultimate flexibility, we recommend sending all your analytical events to Superwall via ``Paywall/Paywall/track(_:_:)-2vkwo``. That way you can retroactively add a paywall to any of your analytical events, should you decide to do so.

### Integrating with Existing Analytics

If you're already set up with an analytics provider, you'll typically have an `Analytics.swift` singleton (or similar) to disperse all your events from. Here's how that file might look:

```swift
import Paywall
import Mixpanel
import Firebase

final class Analytics {
  static var shared = Analytics()
  
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

Therefore you can track all your analytics in one go:
  
```swift
Analytics.shared.track(
  "workout_complete",
  ["total_workouts": 17]
)
```
