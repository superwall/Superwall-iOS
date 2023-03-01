# Setting User Attributes

Set user attributes for use in your paywalls and the dashboard.

## Overview

You can display information about the user on the paywall by setting user attributes.

You do this by passing a `[String: Any?]` dictionary of attributes to ``Superwall/setUserAttributes(_:)``:

```swift
extension SuperwallService {
  static func setUser() async {
    guard let user = Auth.shared.user else {
      return
    }

    var attributes: [String: Any] = [
      "name": user.name,
      "apnsToken": user.apnsTokenString,
      "email": user.email,
      "username": user.username,
      "profilePic": user.profilePicUrl
    ]
    await Superwall.shared.setUserAttributes(attributes)
  }
}
```

This is a merge operation, such that if the existing user attributes dictionary already has a value for a given property, the old value is overwritten. Other existing properties will not be affected.

You can reference user attributes in campaign rules to help decide when to display your paywall. When you configure your paywall, you can also reference the attributes in its text variables. For more information on how to that, [see our docs for configuring variables in the dashboard](https://docs.superwall.com/docs/configuring-a-paywall#configuring-variables).

In the future, you'll be able to use user attributes to email/notify users about discounts.
