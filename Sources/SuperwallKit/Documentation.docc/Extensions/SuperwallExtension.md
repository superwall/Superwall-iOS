# ``SuperwallKit/Superwall``

## Overview

The ``Superwall`` class is used to access all the features of the SDK. Before using any of the features, you must call ``Superwall/configure(apiKey:purchaseController:options:completion:)-52tke`` to configure the SDK.

## Topics

### Configuring the SDK

- <doc:GettingStarted>
- <doc:Ecosystem>
- <doc:AdvancedConfiguration>
- ``configure(apiKey:purchaseController:options:completion:)-52tke``
- ``configure(apiKey:purchaseController:options:completion:)-ds2x``
- ``configure(apiKey:)``
- ``shared``
- ``SuperwallDelegate``
- ``SuperwallDelegateObjc``
- ``delegate``
- ``objcDelegate``
- ``PurchaseController``
- ``PurchaseControllerObjc``
- ``subscriptionStatus``
- ``SubscriptionStatus``
- ``SuperwallOptions``
- ``PaywallOptions``
- ``preloadAllPaywalls()``
- ``preloadPaywalls(forEvents:)``

### Presenting and Dismissing a Paywall

- <doc:TrackingEvents>
- ``track(event:params:paywallOverrides:paywallHandler:)``
- ``track(event:params:products:ignoreSubscriptionStatus:presentationStyleOverride:onSkip:onPresent:onDismiss:)``
- ``track(event:)``
- ``track(event:params:)``
- ``track(event:onSkip:onPresent:onDismiss:)``
- ``track(event:params:onSkip:onPresent:onDismiss:)``
- ``publisher(forEvent:params:paywallOverrides:)``
- ``getTrackResult(forEvent:params:)-1qexk``
- ``getTrackResult(forEvent:params:completion:)``
- ``getTrackResult(forEvent:params:)-2j7qn``
- ``getTrackResult(forEvent:)``
- ``dismiss()-844a9``
- ``dismiss()-4objm``
- ``dismiss(completion:)``
- ``TrackResult``
- ``TrackResultObjc``
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
- ``identify(userId:options:)``
- ``identify(userId:)``
- ``IdentityOptions``
- ``reset()``
- ``setUserAttributes(_:)-1wql2``
- ``setUserAttributes(_:)-8jken``
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

### Helpers
- ``togglePaywallSpinner(isHidden:)``
- ``latestPaywallInfo``
- ``presentedViewController``
- ``userId``
- ``isLoggedIn``
- ``isConfigured``
