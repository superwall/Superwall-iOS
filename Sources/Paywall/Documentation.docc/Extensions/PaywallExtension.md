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
- ``EventName``

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
- ``load(identifier:)``

### Triggering a Paywall

- <doc:Triggering>
- ``trigger(event:params:on:ignoreSubscriptionStatus:onSkip:onPresent:onDismiss:)``
- ``track(_:_:)-2vkwo``
- ``track(_:_:)-7gc4r``
- ``track(name:params:)``
- ``StandardEvent``
- ``TriggerInfo``

### Identifying a User

- <doc:SettingUserAttributes>
- ``identify(userId:)``
- ``setUserAttributes(_:)``
- ``setUserAttributesDictionary(attributes:)``
- ``userAttributes``
- ``reset()``
- ``StandardUserAttribute``
- ``StandardUserAttributeKey``
- ``setUserAttributes(_:custom:)``

### Game Controller

- <doc:GameControllerSupport>
- ``gamepadValueChanged(gamepad:element:)``
- ``isGameControllerEnabled``

### Logging

- ``PaywallDelegate/handleLog(level:scope:message:info:error:)``
- ``Paywall/Paywall/logLevel``
- ``Paywall/Paywall/logScopes``

### Customisation

- ``restoreFailedTitleString``
- ``restoreFailedMessageString``
- ``restoreFailedCloseButtonString``
- ``localizationOverride(localeIdentifier:)``
- ``shouldPreloadTriggers``
- ``shouldAnimatePaywallDismissal``
- ``shouldAnimatePaywallPresentation``
- ``networkEnvironment``
- ``PaywallNetworkEnvironment``
