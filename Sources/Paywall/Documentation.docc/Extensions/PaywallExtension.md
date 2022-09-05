# `Paywall/Paywall`

## Overview

The `Paywall/Paywall` class is used to access all the features of the SDK. Before using any of the features, you must call `Paywall/Paywall/configure(apiKey:userId:delegate:options:)` to configure the SDK.

## Topics

### Configuring the SDK

- <doc:GettingStarted>
- <doc:Ecosystem>
- `configure(apiKey:userId:delegate:options:)`
- `PaywallDelegate`
- `delegate`
- `PaywallOptions`
- `options`
- `PaywallOptions/PaywallNetworkEnvironment`

### Triggering and Dismissing a Paywall

- <doc:Triggering>
- `trigger(event:params:on:products:ignoreSubscriptionStatus:presentationStyleOverride:onSkip:onPresent:onDismiss:)`
- `dismiss(_:)`
- `PaywallInfo`
- `EventName`

### In-App Previews

- <doc:InAppPreviews>
- `handleDeepLink(_:)`

### Presenting and Dismissing a Paywall

- `present(onPresent:onDismiss:onFail:)`
- `present(on:onPresent:onDismiss:onFail:)`
- `present(identifier:on:ignoreSubscriptionStatus:presentationStyleOverride:onPresent:onDismiss:onFail:)`
- `load(identifier:)`

### Identifying a User

- <doc:SettingUserAttributes>
- `identify(userId:)`
- `setUserAttributes(_:)`
- `userAttributes`
- `reset()`

### Game Controller

- <doc:GameControllerSupport>
- `gamepadValueChanged(gamepad:element:)`

### Logging

- `PaywallDelegate/handleLog(level:scope:message:info:error:)`

### Customization

- `localizationOverride(localeIdentifier:)`
- `presentedViewController`
