# ``SuperwallKit/Superwall``

## Overview

The ``Superwall`` class is used to access all the features of the SDK. Before using any of the features, you must call ``Superwall/configure(apiKey:delegate:options:)-65jyx`` to configure the SDK.

## Topics

### Configuring the SDK

- <doc:GettingStarted>
- <doc:Ecosystem>
- <doc:AdvancedConfiguration>
- ``configure(apiKey:delegate:options:)-65jyx``
- ``configure(apiKey:delegate:options:)-48l7e``
- ``shared``
- ``SuperwallDelegate``
- ``SuperwallDelegateObjc``
- ``delegate``
- ``objcDelegate``
- ``SubscriptionController``
- ``SubscriptionControllerObjc``
- ``SuperwallOptions``
- ``PaywallOptions``
- ``options``
- ``preloadAllPaywalls()``
- ``preloadPaywalls(forEvents:)``

### Presenting and Dismissing a Paywall

- <doc:TrackingEvents>
- ``track(event:params:paywallOverrides:paywallHandler:)``
- ``getTrackResult(forEvent:params:)``
- ``getTrackResult(forEvent:params:completion:)``
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

- ``logLevel``
- ``SuperwallDelegate/handleLog(level:scope:message:info:error:)-9kmai``
- ``LogLevel``
- ``LogScope``
- ``SuperwallOptions/Logging-swift.class``

### Customization

- ``localizationOverride(localeIdentifier:)``

### Helper Variables
- ``presentedViewController``
- ``latestPaywallInfo``
- ``userId``
- ``isLoggedIn``
- ``isConfigured``
- ``hasActiveSubscription``
