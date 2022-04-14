# Presenting a Paywall with SwiftUI

Attach a view modifier to present a paywall and receive callbacks associated with the paywall presentation state.

## Overview


To present a paywall in SwiftUI, you attach the `.presentPaywall(isPresented:onPresent:onDismiss:onFail:)` view modifier to a view. It shows the paywall when the Boolean value you provide is `true` and the user doesn't have an active subscription. You can then receive callbacks associated with the paywall presentation state.

> Important: The paywall assigned to the user is determined by your settings in the [Superwall Dashboard](https://superwall.com/dashboard). Presented paywalls are **sticky**. This means that once a user is assigned a paywall, they will continue to see the same paywall, even when the paywall is turned off, unless you reassign them to a new one.

### Attaching the View Modifier

To present a paywall, you attach the `.presentPaywall(isPresented:onPresent:onDismiss:onFail:)` view modifier to a view. You provide a binding to a `Bool` to control when to show the paywall.

For example, here's how you might present a paywall when the user toggles the `showPaywall` variable by tapping on the **Toggle Paywall** button:

```swift
struct ContentView: View {
  @State private var showPaywall = false

  var body: some View {
    Button(
      action: {
        showPaywall.toggle()
      },
      label: {
        Text("Toggle Paywall")
      }
    )
    .presentPaywall(
      isPresented: $showPaywall,
      onPresent: { paywallInfo in
        print("paywall info is", paywallInfo)
      },
      onDismiss: { result in
        switch result.state {
        case .closed:
          print("User dismissed the paywall.")
        case .purchased(productId: let productId):
          print("Purchased a product with id \(productId), then dismissed.")
        case .restored:
          print("Restored purchases, then dismissed.")
        }
      },
      onFail: { error in
        print("did fail", error)
      }
    )
  }
}
```

The `onPresent`, `onDismiss`, and `onFail` callbacks are optional. They provide the following functionality:


|   Parameter  | Type                             | Functionality   |
| ------------ | -------------------------------- | --------------- |
| `onPresent`  | `(PaywallInfo) -> Void`           | A closure that’s called after the paywall is presented. Accepts an optional ``Paywall/PaywallInfo`` object containing information about the paywall. Defaults to `nil`.   |
| `onDismiss`  | `(PaywallDismissalResult) -> Void` | The closure to execute after the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a ``PaywallDismissalResult`` object. This has a ``PaywallDismissalResult/paywallInfo`` property containing information about the paywall and a state that tells you why the paywall was dismissed. This closure will not be called if you programmatically set isPresented to false to dismiss the paywall. Defaults to nil.                |
| `onFail`     | `(NSError) -> Void`                | A closure that’s called when the paywall fails to present, either because an error occurred or because all paywalls are off in the Superwall Dashboard. You should typically fallback to your previous paywall if this happens. Accepts an `NSError` with more details. Defaults to nil. |   
