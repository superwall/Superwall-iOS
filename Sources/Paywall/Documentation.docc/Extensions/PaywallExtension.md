# ``Paywall/Paywall``

## Overview

The ``Paywall/Paywall`` class is used to access all the features of the SDK. Before using any of the features, you must call ``Paywall/Paywall/configure(apiKey:userId:delegate:)`` to configure the SDK.

## Topics

### Configuring the SDK

- <doc:GettingStarted>
- ``configure(apiKey:userId:delegate:)``
- ``PaywallDelegate``
- ``debugMode``
- ``delegate``

### Identifying a User

- <doc:SettingUserAttributes>
- ``identify(userId:)``
- ``setUserAttributes(_:)``
- ``reset()``
- ``userAttributes``

### Presenting and Dismissing a Paywall

- <doc:PresentingInSwiftUI>
- <doc:PresentingInUIKit>
- ``present(onPresent:onDismiss:onFail:)``
- ``present(on:onPresent:onDismiss:onFail:)``
- ``present(identifier:on:ignoreSubscriptionStatus:onPresent:onDismiss:onFail:)``
- ``PaywallInfo``
- ``shouldAnimatePaywallPresentation``
- ``dismiss(_:)``
- ``shouldAnimatePaywallDismissal``

### Triggering a Paywall

- <doc:Triggering>
- ``trigger(event:params:on:ignoreSubscriptionStatus:onSkip:onPresent:onDismiss:)``
- ``track(_:_:)-2vkwo``
- ``TriggerInfo``

### Game Controller

- ``gamepadValueChanged(gamepad:element:)``
- ``isGameControllerEnabled``

