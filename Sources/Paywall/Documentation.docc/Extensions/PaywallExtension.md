# ``Paywall/Paywall``

## Overview

The ``Paywall/Paywall`` class is used to access all the features of the SDK. Before using any of the features, you must call ``Paywall/Paywall/configure(apiKey:userId:delegate:options:)`` to configure the SDK.

## Topics

### Configuring the SDK

- <doc:GettingStarted>
- <doc:Ecosystem>
- ``Paywall/Paywall/configure(apiKey:userId:delegate:options:)``
- ``PaywallDelegate``
- ``delegate``
- ``PaywallOptions``
- ``options``
- ``PaywallOptions/PaywallNetworkEnvironment``

### Presenting and Dismissing a Paywall

- <doc:TrackingEvents>
- ``track(event:params:paywallOverrides:paywallState:)``
- ``track(event:params:paywallOverrides:)``
- ``dismiss(_:)``
- ``PaywallInfo``
- ``EventName``

### In-App Previews

- <doc:InAppPreviews>
- ``handleDeepLink(_:)``

### Identifying a User

- <doc:SettingUserAttributes>
- ``identify(userId:)``
- ``setUserAttributes(_:)``
- ``userAttributes``
- ``reset()``

### Game Controller

- <doc:GameControllerSupport>
- ``gamepadValueChanged(gamepad:element:)``

### Logging

- ``PaywallDelegate/handleLog(level:scope:message:info:error:)``

### Customization

- ``localizationOverride(localeIdentifier:)``
- ``presentedViewController``
