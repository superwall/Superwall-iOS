# Paywall

`Paywall` is the primary class for integrating Superwall into your application. To learn more, read our iOS getting started guide:​ https:​//docs.superwall.me/docs/ios

``` swift
public class Paywall: NSObject 
```

## Inheritance

`NSObject`, `SKPaymentTransactionObserver`

## Nested Type Aliases

### `PurchaseCompletionBlock`

Completion block of type `(Bool) -> ()` that is optionally passed through `Paywall.present()`. Gets called when the paywall is dismissed by the user, by way or purchasing, restoring or manually dismissing. Accepts a BOOL that is `true` if the product is purchased or restored, and `false` if the user manually dismisses the paywall.
Please note:​ This completion is NOT called when  `Paywall.dismiss()` is manually called by the developer.

``` swift
public typealias PurchaseCompletionBlock = (Bool) -> ()
```

### `FallbackBlock`

Completion block that is optionally passed through `Paywall.present()`. Gets called if an error occurs while presenting a Superwall paywall, or if all paywalls are set to off in your dashboard. It's a good idea to add your legacy paywall presentation logic here just in case :​)

``` swift
public typealias FallbackBlock = () -> ()
```

## Properties

### `debugMode`

Prints debug logs to the console if set to `true`. Default is `false`

``` swift
public static var debugMode = false
```

### `delegate`

The object that acts as the delegate of Paywall. Required implementations include `userDidInitiateCheckout(for product:​ SKProduct)` and `shouldTryToRestore()`.

``` swift
public static var delegate: PaywallDelegate? = nil
```

## Methods

### `track(_:_:)`

Tracks a standard event with properties (See `Paywall.StandardEvent` for options). Properties are optional and can be added only if needed. You'll be able to reference properties when creating rules for when paywalls show up.

``` swift
public static func track(_ event: StandardEvent, _ params: [String: Any] = [:]) 
```

Example:

``` swift
Paywall.track(.deepLinkOpen(url: someURL))
Paywall.track(.signUp, ["campaignId": "12312341", "source": "Facebook Ads"]
```

#### Parameters

  - event: A `StandardEvent` enum, which takes default parameters as inputs.
  - params: Custom parameters you'd like to include in your event. Remember, keys begining with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.

### `track(_:_:)`

Tracks a custom event with properties. Remember to check `Paywall.StandardEvent` to determine if you should be tracking a standard event instead. Properties are optional and can be added only if needed. You'll be able to reference properties when creating rules for when paywalls show up.

``` swift
public static func track(_ name: String, _ params: [String: Any]) 
```

Example:

``` swift
Paywall.track("onboarding_skip", ["steps_completed": 4])
```

#### Parameters

  - event: The name of your custom event
  - params: Custom parameters you'd like to include in your event. Remember, keys begining with `$` are reserved for Superwall and will be dropped. They will however be included in `PaywallDelegate.shouldTrack(event: String, params: [String: Any])` for your own records. Values can be any JSON encodable value or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.

### `setUserAttributes(_:custom:)`

Sets additional information on the user object in Superwall. Useful for analytics and conditional paywall rules you may define in the web dashboard. Remember, attributes are write-only by the SDK, and only require your public key. They should not be used as a source of truth for sensitive information.

``` swift
public static func setUserAttributes(_ standard: StandardUserAttribute..., custom: [String: Any?] = [:]) 
```

Example:

``` swift
Superwall.setUserAttributes(.firstName("Jake"), .lastName("Mor"), custom: properties)
```

#### Parameters

  - standard: Zero or more `SubscriberUserAttribute` enums describing standard user attributes.
  - custom: A `[String: Any?]` map used to describe any custom attributes you'd like to store to the user. Remember, keys begining with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.

### `load(completion:)`

Pre-loads your paywall so it loads instantly on `Paywall.present()`.

``` swift
public static func load(completion: ((Bool) -> ())? = nil) 
```

#### Parameters

  - completion: A completion block of type `((Bool) -> ())?`, defaulting to nil if not provided. `true` on success, and `false` on failure.

### `configure(apiKey:userId:)`

Configures an instance of Superwall's Paywall SDK with a specified API key. If you don't pass through a userId, we'll create one for you. Calling `Paywall.identify(userId:​ String)` in the future will automatically alias these two for simple reporting.

``` swift
@discardableResult
    public static func configure(apiKey: String, userId: String? = nil) -> Paywall 
```

#### Parameters

  - apiKey: Your Public API Key from: https://superwall.me/applications/1/settings/keys
  - userId: Your user's unique identifier, as defined by your backend system.

### `identify(userId:)`

Links your userId to Superwall's automatically generated Alias. Call this as soon as you have a userId.

``` swift
@discardableResult
    public static func identify(userId: String) -> Paywall 
```

#### Parameters

  - userId: Your user's unique identifier, as defined by your backend system.

### `reset()`

Resets the userId stored by Superwall. Call this when your user signs out.

``` swift
@discardableResult
    public static func reset() -> Paywall 
```

### `dismiss(_:)`

Dismisses the presented paywall. Doesn't trigger a `PurchaseCompletionBlock` call if provided during `Paywall.present()`, since this action is developer initiated.

``` swift
public static func dismiss(_ completion: (()->())? = nil) 
```

#### Parameters

  - completion: A completion block of type `(()->())? = nil` that gets called after the paywall is dismissed.

### `present(cached:presentationCompletion:purchaseCompletion:)`

Presents a paywall to the user.

``` swift
public static func present(cached: Bool, presentationCompletion:  (()->())? = nil, purchaseCompletion: PurchaseCompletionBlock? = nil) 
```

#### Parameters

  - cached: Determines if Superwall shoudl re-fetch a paywall from the user. You should typically set this to `false` only if you think your user may now conditionally match a rule for another paywall. Defaults to `true`.
  - presentationCompletion: A completion block that gets called immediately after the paywall is presented. Defaults to  `nil`,
  - purchaseCompletion: Gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the product is purchased or restored, and `false` if the paywall is manually dismissed by the user.

### `present(presentationCompletion:purchaseCompletion:)`

Presents a paywall to the user.

``` swift
public static func present(presentationCompletion: (()->())? = nil, purchaseCompletion: PurchaseCompletionBlock? = nil) 
```

#### Parameters

  - presentationCompletion: A completion block that gets called immediately after the paywall is presented. Defaults to  `nil`,
  - purchaseCompletion: Gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the product is purchased or restored, and `false` if the paywall is manually dismissed by the user.

### `present(purchaseCompletion:)`

Presents a paywall to the user.

``` swift
public static func present(purchaseCompletion: PurchaseCompletionBlock? = nil) 
```

#### Parameters

  - purchaseCompletion: Gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the product is purchased or restored, and `false` if the paywall is manually dismissed by the user.

### `present(cached:)`

Presents a paywall to the user.

``` swift
public static func present(cached: Bool) 
```

#### Parameters

  - cached: Determines if Superwall shoudl re-fetch a paywall from the user. You should typically set this to `false` only if you think your user may now conditionally match a rule for another paywall. Defaults to `true`.

### `present()`

Presents a paywall to the user.

``` swift
public static func present() 
```

### `present(on:cached:presentationCompletion:purchaseCompletion:fallback:)`

Presents a paywall to the user.

``` swift
public static func present(on viewController: UIViewController? = nil, cached: Bool = true, presentationCompletion: (()->())? = nil, purchaseCompletion: PurchaseCompletionBlock? = nil, fallback: FallbackBlock? = nil) 
```

#### Parameters

  - on: The view controller to present the paywall on. Presents on the `keyWindow`'s `rootViewController` if `nil`. Defaults to `nil`.
  - cached: Determines if Superwall shoudl re-fetch a paywall from the user. You should typically set this to `false` only if you think your user may now conditionally match a rule for another paywall. Defaults to `true`.
  - presentationCompletion: A completion block that gets called immediately after the paywall is presented. Defaults to  `nil`,
  - purchaseCompletion: Gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the product is purchased or restored, and `false` if the paywall is manually dismissed by the user.

### `paymentQueue(_:updatedTransactions:)`

``` swift
public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) 
```
