# Custom Paywall Buttons

Linking your own logic to buttons within the paywall.

## Overview

The SDK automatically recognizes elements in the paywall tagged with `data-pw-restore`, `data-pw-close` and `data-pw-purchase` and links their button taps to corresponding logic in either the SDK or the delegate.

However, the SDK also lets you add your own custom identifiers to buttons, allowing you to tie any button tap in your paywall to logic in your application.

For example, simply adding `data-pw-custom="help_center"` to a button in your HTML paywall gives you the opportunity to present a help center whenever that button is pressed. To set this up, implement the ``PaywallDelegate/handleCustomPaywallAction(withName:)`` in your ``PaywallDelegate``:

```swift
extension PaywallService: PaywallDelegate {
  func handleCustomPaywallAction(withName name: String) {
    if name == "help_center" {
      HelpCenterManager.present()
    }
  }
}
```
