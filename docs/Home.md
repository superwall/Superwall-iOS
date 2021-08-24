# Types

  - [Paywall](/Paywall):
    `Paywall` is the primary class for integrating Superwall into your application. To learn more, read our iOS getting started guide: https://docs.superwall.me/docs/ios
  - [Paywall.StandardEvent](/Paywall_StandardEvent):
    Standard events for use in conjunction with `Paywall.track(_ event: StandardEvent, _ params: [String: Any] = [:])`.
  - [Paywall.StandardEventName](/Paywall_StandardEventName):
    Used internally, please ignore.
  - [Paywall.StandardUserAttributeKey](/Paywall_StandardUserAttributeKey):
    Used internally, please ignore.
  - [Paywall.StandardUserAttribute](/Paywall_StandardUserAttribute):
    Standard user attributes to be used in conjunction with `setUserAttributes(_ standard: StandardUserAttribute..., custom: [String: Any?] = [:])`.

# Protocols

  - [PaywallDelegate](/PaywallDelegate):
    Methods for managing important Paywall lifecycle events. For example, telling the developer when to initiate checkout on a specific `SKProduct` and when to try to restore a transaction. Also includes hooks for you to log important analytics events to your product analytics tool.
