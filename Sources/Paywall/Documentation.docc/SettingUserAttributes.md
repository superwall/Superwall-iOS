# Setting User Attributes

Set user attributes for use in your paywalls and the dashboard.

## Overview

You can display information about the user on the paywall by setting user attributes.

You do this by passing a `[String: Any]` dictionary of attributes to ``Paywall/Paywall/setUserAttributes(_:)``:

```swift
extension PaywallService {
  static func setUser() {
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
    Paywall.setUserAttributes(attributes)
  }
}
```

Then, when you set up your paywall, you can reference the attributes in its text variables. For more information on how to that, [see our docs for configuring variables in the dashboard](https://docs.superwall.com/docs/configuring-a-paywall#configuring-variables).

In the future, you'll be able to use user attributes to email/notify users about discounts.
