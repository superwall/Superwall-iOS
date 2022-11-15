# Third-Party Analytics

Tracking events sent via the ``SuperwallDelegate`` in your own analytics.

## Overview

Superwall automatically tracks events to do with the paywall for you (see ``SuperwallEvent`` for a full list). You can use ``SuperwallKit/SuperwallDelegate/didTrackSuperwallEvent(_:)-n6x1`` to send these events to your own analytics service, such as Mixpanel.

## Tracking Analytical Events

The ``SuperwallDelegate`` has an optional function called ``SuperwallDelegate/didTrackSuperwallEvent(_:)-n6x1``. Any time an event occurs on the paywall, this method gets called. You can implement it like this:

```swift
extension SuperwallService: SuperwallDelegate {
  func didTrackSuperwallEvent(_ info: SuperwallEventInfo) {
    print("analytics event called", result.event.description)

    // Uncomment if you want to get a dictionary of params associated with the event:
    // print(result.params)

    switch result.event {
    case .firstSeen:
      break
    case .appOpen:
      break
    case .appLaunch:
      break
    case .appInstall:
      break
    case .sessionStart:
      break
    case .appClose:
      break
    case .deepLink(let url):
      break
    case .triggerFire(let eventName, let result):
      break
    case .paywallOpen(let paywallInfo):
      break
    case .paywallClose(let paywallInfo):
      break
    case .transactionStart(let product, let paywallInfo):
      break
    case .transactionFail(let error, let paywallInfo):
      break
    case .transactionAbandon(let product, let paywallInfo):
      break
    case .transactionComplete(let transaction, let product, let paywallInfo):
      break
    case .subscriptionStart(let product, let paywallInfo):
      break
    case .freeTrialStart(let product, let paywallInfo):
      break
    case .transactionRestore(let paywallInfo):
      break
    case .userAttributes(let attributes):
      break
    case .nonRecurringProductPurchase(let product, let paywallInfo):
      break
    case .paywallResponseLoadStart(let triggeredEventName):
      break
    case .paywallResponseLoadNotFound(let triggeredEventName):
      break
    case .paywallResponseLoadFail(let triggeredEventName):
      break
    case .paywallResponseLoadComplete(let triggeredEventName, let paywallInfo):
      break
    case .paywallWebviewLoadStart(let paywallInfo):
      break
    case .paywallWebviewLoadFail(let paywallInfo):
      break
    case .paywallWebviewLoadComplete(let paywallInfo):
      break
    case .paywallWebviewLoadTimeout(let paywallInfo):
      break
    case .paywallProductsLoadStart(let triggeredEventName, let paywallInfo):
      break
    case .paywallProductsLoadFail(let triggeredEventName, let paywallInfo):
      break
    case .paywallProductsLoadComplete(let triggeredEventName):
      break
    }
  }
}
```
