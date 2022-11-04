# Third-Party Analytics

Tracking events sent via the ``SuperwallDelegate`` in your own analytics.

## Overview

Superwall automatically tracks events to do with the paywall for you (see ``SuperwallEvent`` for a full list). You can use ``SuperwallKit/SuperwallDelegate/trackAnalyticsEvent(withName:params:)`` to send these events to your own analytics service, such as Mixpanel.

## Tracking Analytical Events

The ``SuperwallDelegate`` has an optional function called ``SuperwallDelegate/trackAnalyticsEvent(withName:params:)``. Any time an event occurs on the paywall, this method gets called. You can implement it like this:

```swift
extension SuperwallService: SuperwallDelegate {
  func trackAnalyticsEvent(
    withName name: String,
    params: [String: Any]
  ) {
    MyAnalyticsService.shared.track(name, params)
  }
}
```

Or if you'd like to override our naming convention, you can initialize a ``SuperwallEvent`` and use a switch statement over the possible cases:

```swift
func trackAnalyticsEvent(
  withName name: String,
  params: [String: Any]
) {
  guard let event = SuperwallEvent(rawValue: name) else {
    return
  } 
  switch event {
  case .firstSeen:
    // Track your custom event
  case .appOpen:
    // Track your custom event
  case .appLaunch:
   // Track your custom event
  case .appInstall:
    // Track your custom event
  case .sessionStart:
    // Track your custom event
  case .appClose:
    // Track your custom event
  case .deepLink:
    // Track your custom event
  case .trackEvent:
    // Track your custom event
  case .paywallOpen:
    // Track your custom event
  case .paywallClose:
    // Track your custom event
  case .transactionStart:
    // Track your custom event
  case .transactionFail:
    // Track your custom event
  case .transactionAbandon:
    // Track your custom event
  case .transactionComplete:
    // Track your custom event
  case .subscriptionStart:
    // Track your custom event
  case .freeTrialStart:
    // Track your custom event
  case .transactionRestore:
    // Track your custom event
  case .userAttributes:
    // Track your custom event
  case .nonRecurringProductPurchase:
    // Track your custom event
  case .paywallResponseLoadStart:
    // Track your custom event
  case .paywallResponseLoadNotFound:
    // Track your custom event
  case .paywallResponseLoadFail:
    // Track your custom event
  case .paywallResponseLoadComplete:
    // Track your custom event
  case .paywallWebviewLoadStart:
    // Track your custom event
  case .paywallWebviewLoadFail:
    // Track your custom event
  case .paywallWebviewLoadComplete:
    // Track your custom event
  case .paywallWebviewLoadTimeout:
    // Track your custom event
  case .paywallProductsLoadStart:
    // Track your custom event
  case .paywallProductsLoadFail:
    // Track your custom event
  case .paywallProductsLoadComplete:
    // Track your custom event
  }
}
```
