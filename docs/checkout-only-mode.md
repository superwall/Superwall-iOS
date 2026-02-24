# Checkout-Only Mode

## Overview

Checkout-only mode is an opt-in feature for web2app flows where users have already seen a purchase offer in a web funnel and should be taken directly to the Stripe checkout sheet, skipping the intermediate Superwall paywall UI.

**Before (default behavior):**
Web funnel ("Start your trial") → Intermediate Superwall paywall → Stripe checkout sheet

**After (checkout-only mode):**
Web funnel ("Start your trial") → Loading spinner → Stripe checkout sheet

## Usage

### Quick Start (Convenience Method)

```swift
// With a feature gate
Superwall.shared.openWebCheckout(
  forPlacement: "checkout_placement",
  handler: handler
) {
  // Feature to unlock after purchase
  unlockPremiumContent()
}

// Without a feature gate
Superwall.shared.openWebCheckout(
  forPlacement: "checkout_placement",
  handler: handler
)
```

### Using PaywallOverrides Directly

If you need more control (e.g., overriding products), you can use `PaywallOverrides` with the `checkoutOnly` parameter via the standard `register()` flow:

```swift
let overrides = PaywallOverrides(
  productsByName: ["primary": myProduct],
  checkoutOnly: true
)
```

## How It Works

1. The paywall webview loads **invisibly** (hidden from the user) while a native `UIActivityIndicatorView` spinner is shown.
2. When the paywall's JavaScript fires the `openPaymentSheet` event, the spinner is removed and the Stripe checkout sheet is presented.
3. When the checkout sheet is dismissed:
   - If the user completed a purchase, the normal purchase flow continues.
   - If the user cancelled, the invisible paywall is automatically dismissed.
4. If the webview fails to load, the error handler is called and the view is dismissed.

## Dashboard Requirement

The Superwall paywall assigned to the placement **must be configured to auto-trigger the purchase action on page load**. This can be done by adding JavaScript in the Superwall paywall editor that immediately fires the checkout/purchase event when the page loads, bypassing any user interaction with the paywall itself.

## File Changes

| File | Change | Reason |
|------|--------|--------|
| `PaywallOverrides.swift` | Added `checkoutOnly: Bool` property (default `false`) to all initializers | Provides the opt-in flag for checkout-only mode without affecting existing behavior |
| `PublicPresentation.swift` | Added `openWebCheckout(forPlacement:)` convenience methods; threaded `paywallOverrides` through `internallyRegister()` | Gives developers a simple public API and ensures overrides reach the paywall presentation pipeline |
| `PaywallViewController.swift` | Added `isCheckoutOnly` computed property, `setupCheckoutOnlyMode()` / `removeCheckoutOnlySpinner()` helpers; modified `loadingStateDidChange`, `openPaymentSheet`, and `handleWebViewFailure` | Implements the invisible-webview + spinner UX, prevents the webview from becoming visible, removes the spinner when checkout opens, auto-dismisses the paywall on checkout close, and cleans up on webview failure |
| `PaywallOverridesTests.swift` | New test file with 5 tests | Verifies `checkoutOnly` defaults to `false` in all initializers and can be set to `true` |
| `CHANGELOG.md` | Added entry for `openWebCheckout()` API | Documents the new feature for SDK consumers |

## Backward Compatibility

This feature is **fully backward compatible**:

- `checkoutOnly` defaults to `false` in every `PaywallOverrides` initializer
- Existing `register()` calls are unaffected
- The `openWebCheckout()` methods are additive — no existing APIs are modified
- No changes to the Superwall dashboard are required for non-checkout-only flows
