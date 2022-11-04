# ``SuperwallKit/SuperwallDelegate``

@Metadata {
  @DocumentationExtension(mergeBehavior: append)
}

## Topics

### Required Methods

- ``purchase(product:)``
- ``restorePurchases(completion:)``
- ``isUserSubscribed()``

### Optional Methods

- ``trackAnalyticsEvent(withName:params:)``
- ``handleCustomPaywallAction(withName:)``
- ``handleLog(level:scope:message:info:error:)``
- ``willDismissPaywall()``
- ``didDismissPaywall()``
- ``willPresentPaywall()``
- ``didPresentPaywall()``
- ``willOpenDeepLink(url:)``
- ``willOpenURL(url:)``
