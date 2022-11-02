# ``Superwall/Superwall``

## Overview

The ``Superwall/Superwall`` class is used to access all the features of the SDK. Before using any of the features, you must call ``Superwall/Superwall/configure(apiKey:delegate:options:)-7doe5`` to configure the SDK.

## Topics

### Configuring the SDK

- <doc:GettingStarted>
- <doc:Ecosystem>
- ``configure(apiKey:delegate:options:)``
- ``SuperwallDelegate``
- ``delegate``
- ``SuperwallOptions``
- ``PaywallOptions``
- ``options``
- ``preloadAllPaywalls()``
- ``preloadPaywalls(forTriggers:)``

### Presenting and Dismissing a Paywall

- <doc:TrackingEvents>
- ``track(event:params:paywallOverrides:paywallState:)``
- ``track(event:params:paywallOverrides:)``
- ``track(event:params:products:ignoreSubscriptionStatus:presentationStyleOverride:onSkip:onPresent:onDismiss:)``
- ``dismiss()``
- ``dismiss(_:)``
- ``PaywallInfo``
- ``SuperwallEvent``

### In-App Previews

- <doc:InAppPreviews>
- ``handleDeepLink(_:)``

### Identifying a User

- <doc:SettingUserAttributes>
- ``createAccount(userId:)``
- ``logIn(userId:)``
- ``logIn(userId:completion:)``
- ``logOut()``
- ``logOut(completion:)``
- ``reset()``
- ``reset(completion:)``
- ``setUserAttributes(_:)``
- ``setUserAttributesDictionary(_:)``
- ``userAttributes``

### Game Controller

- <doc:GameControllerSupport>
- ``gamepadValueChanged(gamepad:element:)``

### Logging

- ``SuperwallDelegate/handleLog(level:scope:message:info:error:)``

### Customization

- ``localizationOverride(localeIdentifier:)``

### Helper Variables
- ``presentedViewController``
- ``latestPaywallInfo``
- ``userId``
