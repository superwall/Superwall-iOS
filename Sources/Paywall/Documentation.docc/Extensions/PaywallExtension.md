# ``Paywall/Paywall``

## Topics

### Configuring the SDK

- ``configure(apiKey:userId:delegate:)``
- ``PaywallDelegate``
- ``debugMode``
- ``delegate``

### Identifying a User

- ``identify(userId:)``
- ``setUserAttributes(_:)``
- ``reset()``
- ``userAttributes``


### Presenting and Dismissing a Paywall

- <doc:Presenting>
- ``present(onPresent:onDismiss:onFail:)``
- ``present(on:onPresent:onDismiss:onFail:)``
- ``present(identifier:on:ignoreSubscriptionStatus:onPresent:onDismiss:onFail:)``
- ``PaywallInfo``
- ``shouldAnimatePaywallPresentation``
- ``dismiss(_:)``
- ``shouldAnimatePaywallDismissal``

### Triggering a Paywall

- ``trigger(event:params:on:ignoreSubscriptionStatus:onSkip:onPresent:onDismiss:)``
- ``track(_:_:)-2vkwo``
- ``TriggerInfo``

### Game Controller

- ``gamepadValueChanged(gamepad:element:)``
- ``isGameControllerEnabled``

