# ``SuperwallKit/Superwall``

## Overview

The ``SuperwallKit/Superwall`` class is used to access all the features of the SDK. Before using any of the features, you must call ``SuperwallKit/Superwall/configure(apiKey:delegate:options:)-65jyx`` to configure the SDK.

## Topics

### Configuring the SDK

- <doc:GettingStarted>
- <doc:Ecosystem>
- ``configure(apiKey:delegate:options:)-65jyx``
- ``configure(apiKey:delegate:options:)-48l7e``
- ``SuperwallDelegate``
- ``SuperwallDelegateObjc``
- ``delegate``
- ``objcDelegate``
- ``SuperwallOptions``
- ``PaywallOptions``
- ``options``
- ``preloadAllPaywalls()``
- ``preloadPaywalls(forEvents:)``

### Presenting and Dismissing a Paywall

- <doc:TrackingEvents>
- ``track(event:params:paywallOverrides:paywallHandler:)``
- ``getTrackResult(forEvent:params:)``
- ``getTrackInfo(forEvent:params:)``
- ``publisher(forEvent:params:paywallOverrides:)``
- ``track(event:params:products:ignoreSubscriptionStatus:presentationStyleOverride:onSkip:onPresent:onDismiss:)``
- ``dismiss()``
- ``dismiss(_:)``
- ``PaywallInfo``
- ``SuperwallEvent``
- ``SuperwallEventObjc``
- ``PaywallSkippedReason``
- ``PaywallSkippedReasonObjc``

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
- ``removeUserAttributes(_:)``
- ``userAttributes``

### Game Controller

- <doc:GameControllerSupport>
- ``gamepadValueChanged(gamepad:element:)``

### Logging

- ``SuperwallDelegate/handleLog(level:scope:message:info:error:)-9kmai``

### Customization

- ``localizationOverride(localeIdentifier:)``

### Helper Variables
- ``presentedViewController``
- ``latestPaywallInfo``
- ``userId``
- ``isLoggedIn``
