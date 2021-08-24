# Paywall.StandardUserAttribute

Standard user attributes to be used in conjunction with `setUserAttributes(_ standard:​ StandardUserAttribute..., custom:​ [String:​ Any?] = [:​])`.

``` swift
public enum StandardUserAttribute 
```

## Enumeration Cases

### `id`

Standard user attribute containing your user's internal identifier. This attribute is automatically added and you don't really need to include it.

``` swift
case id(_ s: String)
```

### `firstName`

Standard user attribute containing your user's first name.

``` swift
case firstName(_ s: String)
```

### `lastName`

Standard user attribute containing your user's last name.

``` swift
case lastName(_ s: String)
```

### `email`

Standard user attribute containing your user's email address.

``` swift
case email(_ s: String)
```

### `phone`

Standard user attribute containing your user's phone number, without a country code.

``` swift
case phone(_ s: String)
```

### `fullPhone`

Standard user attribute containing your user's full phone number, country code included.

``` swift
case fullPhone(_ s: String)
```

### `phoneCountryCode`

Standard user attribute containing your user's telephone country code.

``` swift
case phoneCountryCode(_ s: String)
```

### `fcmToken`

Standard user attribute containing your user's FCM token to send push notifications via Firebase.

``` swift
case fcmToken(_ s: String)
```

### `apnsToken`

Standard user attribute containing your user's APNS token to send push notification via APNS.

``` swift
case apnsToken(_ s: String)
```

### `createdAt`

Standard user attribute containing your user's account creation date.

``` swift
case createdAt(_ d: Date)
```
