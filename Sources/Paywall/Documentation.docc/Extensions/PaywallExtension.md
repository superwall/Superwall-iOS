# ``Paywall/Paywall``

## Overview

The ``Paywall/Paywall`` class is used to access all the features of the SDK. Before using any of the features, you must call ``Paywall/Paywall/configure(apiKey:userId:delegate:)`` to configure the SDK.

## Topics

### Configuring the SDK

- <doc:GettingStarted>
- <doc:Ecosystem>
- ``configure(apiKey:userId:delegate:)``
- ``PaywallDelegate``
- ``debugMode``
- ``delegate``
- ``EventName``

### Triggering and Dismissing a Paywall

- <doc:Triggering>
- ``trigger(event:params:on:ignoreSubscriptionStatus:onSkip:onPresent:onDismiss:)``
- ``track(_:_:)-2vkwo``
- ``dismiss(_:)``
- ``track(_:_:)-7gc4r``
- ``track(name:params:)``
- ``StandardEvent``

### In-App Previews
- <doc:InAppPreviews>
- ``handleDeepLink(_:)``

### Presenting and Dismissing a Paywall

- ``present(onPresent:onDismiss:onFail:)``
- ``present(on:onPresent:onDismiss:onFail:)``
- ``present(identifier:on:ignoreSubscriptionStatus:onPresent:onDismiss:onFail:)``
- ``PaywallInfo``
- ``load(identifier:)``

### Identifying a User

- <doc:SettingUserAttributes>
- ``identify(userId:)``
- ``setUserAttributes(_:)``
- ``userAttributes``
- ``reset()``
- ``setUserAttributesDictionary(attributes:)``
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

### Customization

- ``automaticallyDismiss``
- ``restoreFailedTitleString``
- ``restoreFailedMessageString``
- ``restoreFailedCloseButtonString``
- ``localizationOverride(localeIdentifier:)``
- ``shouldPreloadTriggers``
- ``shouldAnimatePaywallDismissal``
- ``shouldAnimatePaywallPresentation``
- ``networkEnvironment``
- ``PaywallNetworkEnvironment``
