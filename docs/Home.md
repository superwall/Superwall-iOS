# Types

  - [Paywall](./Paywall):
    `Paywall` is the primary class for integrating Superwall into your application. To learn more, read our iOS getting started guide: https://docs.superwall.me/docs/ios
  - [Paywall.StandardEvent](./Paywall_StandardEvent):
    Standard events for use in conjunction with `Paywall.track(_ event: StandardEvent, _ params: [String: Any] = [:])`.
  - [Paywall.StandardEventName](./Paywall_StandardEventName):
    Used internally, please ignore.
  - [Paywall.StandardUserAttributeKey](./Paywall_StandardUserAttributeKey):
    Used internally, please ignore.
  - [Paywall.StandardUserAttribute](./Paywall_StandardUserAttribute):
    Standard user attributes to be used in conjunction with `setUserAttributes(_ standard: StandardUserAttribute..., custom: [String: Any?] = [:])`.
  - [Paywall.EventName](./Paywall_EventName):
    These are the types of events we send to Paywall's delegate `shouldTrack` method
  - [Paywall.PaywallNetworkEnvironment](./Paywall_PaywallNetworkEnvironment):
    WARNING: Only use this enum to set `Paywall.networkEnvironment` if told so explicitly by the Superwall team.

# Protocols

  - [PaywallDelegate](./PaywallDelegate):
    Methods for managing important Paywall lifecycle events. For example, telling the developer when to initiate checkout on a specific `SKProduct` and when to try to restore a transaction. Also includes hooks for you to log important analytics events to your product analytics tool.
