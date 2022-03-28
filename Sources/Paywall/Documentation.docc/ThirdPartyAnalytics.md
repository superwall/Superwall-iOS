# Third-Party Analytics

Tracking events sent via the ``PaywallDelegate`` in your own analytics.

## Overview

Superwall automatically tracks analytical events to do with the paywall for you (see <doc:AutomaticallyTrackedEvents> for a full list). You can use ``Paywall/PaywallDelegate/trackAnalyticsEvent(withName:params:)`` to send these events to your own analytics service, such as Mixpanel.

## Tracking Analytical Events

The ``PaywallDelegate`` has an optional function called ``PaywallDelegate/trackAnalyticsEvent(withName:params:)``. Any time an event occurs on the paywall, this method gets called. You can implement it like this:

```swift
extension PaywallService: PaywallDelegate {
  func trackAnalyticsEvent(
    withName name: String,
    params: [String: Any]
  ) {
    MyAnalyticsService.shared.track(name, params)
  }
}
```

Or if you'd like to override our naming convention, you can initialize a ``Paywall/Paywall/EventName`` and use a switch statement over the possible cases:

```swift
func trackAnalyticsEvent(
  withName name: String,
  params: [String: Any]
) {
  guard let event = Paywall.EventName(rawValue: name) else {
    return
  } 
  switch event {
  case .firstSeen:
    // track your custom event
  case .appOpen:
    // track your custom event
  case .appLaunch:
    // track your custom event
  case .appClose:
    // track your custom event
  case .sessionStart:
    // track your custom event
  case .paywallOpen:
    // track your custom event
  case .paywallClose:
    // track your custom event
  case .transactionStart:
    // track your custom event
  case .transactionFail:
    // track your custom event
  case .transactionAbandon:
    // track your custom event
  case .transactionComplete:
    // track your custom event
  case .subscriptionStart:
    // track your custom event
  case .freeTrialStart:
    // track your custom event
  case .transactionRestore:
    // track your custom event
  case .nonRecurringProductPurchase:
    // track your custom event
  case .paywallResponseLoadStart:
    // track your custom event
  case .paywallResponseLoadFail:
    // track your custom event
  case .paywallResponseLoadComplete:
    // track your custom event
  case .paywallWebviewLoadStart:
    // track your custom event
  case .paywallWebviewLoadFail:
    // track your custom event
  case .paywallWebviewLoadComplete:
    // track your custom event
  }
}
```
