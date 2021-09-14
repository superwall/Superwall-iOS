# Paywall.StandardEvent

Standard events for use in conjunction with `Paywall.track(_ event:​ StandardEvent, _ params:​ [String:​ Any] = [:​])`.

``` swift
public enum StandardEvent 
```

## Enumeration Cases

### `deepLinkOpen`

Standard even used to track when a user opens your application by way of a deep link.

``` swift
case deepLinkOpen(deepLinkUrl: URL)
```

### `onboardingStart`

Standard even used to track when a user begins onboarding.

``` swift
case onboardingStart
```

### `onboardingComplete`

Standard even used to track when a user completes onboarding.

``` swift
case onboardingComplete
```

### `pushNotificationReceive`

Standard even used to track when a user receives a push notification.

``` swift
case pushNotificationReceive(superwallId: String? = nil)
```

### `pushNotificationOpen`

Standard even used to track when a user launches your application by way of a push notification.

``` swift
case pushNotificationOpen(superwallId: String? = nil)
```

### `coreSessionStart`

Standard even used to track when a user completes a 'Core Session' of your app. For example, if your app is a workout app, you should call this when a workout begins.

``` swift
case coreSessionStart
```

### `coreSessionAbandon`

Standard even used to track when a user completes a 'Core Session' of your app. For example, if your app is a workout app, you should call this when a workout is cancelled or aborted.

``` swift
case coreSessionAbandon
```

### `coreSessionComplete`

Standard even used to track when a user completes a 'Core Session' of your app. For example, if your app is a workout app, you should call this when a workout is completed.

``` swift
case coreSessionComplete
```

### `signUp`

Standard even used to track when a user signs up.

``` swift
case signUp
```

### `logIn`

Standard even used to track when a user logs in to your application.

``` swift
case logIn
```

### `logOut`

Standard even used to track when a user logs out of your application. Not to be confused with `Paywall.reset()` — this event is strictly for analytical purposes.

``` swift
case logOut
```

### `userAttributes`

WARNING:​ Use `setUserAttributes(_ standard:​ StandardUserAttribute..., custom:​ [String:​ Any?] = [:​])` instead.

``` swift
case userAttributes(standard: [StandardUserAttributeKey: Any?], custom: [String: Any?])
```

### `base`

WARNING:​ This is used internally, ignore please

``` swift
case base(name: String, params: [String: Any])
```
