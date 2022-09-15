# Tracking Events

Show a paywall in your app in response to a tracked event.

## Overview

You can retroactively decide where and when to show a paywall in your app by tracking events.

Events are added to campaigns on the [Superwall Dashboard](https://superwall.com/dashboard) and are tracked via the SDK. The SDK listens for these events and evaluates their rules to determine whether or not to show a paywall.

When a user is assigned a paywall within a rule, they will continue to see that paywall unless you remove the paywall from the rule or reset assignments to the paywall.

In addition to your own events, you can add the Superwall events `app_install`, `app_launch`, and `session_start` to a campaign. See [automatically tracked events](<doc:AutomaticallyTrackedEvents>) for more.

## Presenting a Paywall

When you sign up for a Superwall account, we give you an example paywall and campaign to test your integration. The example campaign contains an event called `campaign_trigger`, which you'll track in your app when you want to show the paywall.

For both SwiftUI and UIKit apps, you use ``Paywall/Paywall/track(event:params:paywallOverrides:paywallState:)`` to track events:

```swift
Superwall.track(
  event: "campaign_trigger"
) { paywallState in
  switch paywallState {
  case .presented(let paywallInfo):
    break
  case .dismissed(let result):
    break
  case .skipped(let reason):
    break
}
```

In this example, you're tracking the event `campaign_trigger`. You then utilize the optional `paywallState` callback to handle the paywall presentation state. You can also pass parameters to be used in rules and overrides to replace default paywall functionality.

We recommend tracking all of your analytical events to Superwall. That way you can retroactively add a paywall to any of your events, should you decide to.

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
    Superwall.track(
      event: event,
      params: properties
    )
    
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

Now that you've presented the example paywall, it's time to set up your own paywall. First you'll need to [build your paywall](https://docs.superwall.com/docs/overview). Next, you need to [configure your paywall](https://docs.superwall.com/docs/configuring-a-paywall) and [create a campaign](https://docs.superwall.com/docs/campaigns). You can then use this in your app in the same way as you did above!
