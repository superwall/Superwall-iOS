# Checkout-Only Mode

## Overview

Checkout-only mode is an opt-in feature for **web2app flows** where users have already seen a purchase offer in a web funnel and should be taken directly to the Stripe checkout sheet, skipping the intermediate Superwall paywall UI.

**Before (default behavior):**
Web funnel ("Start your trial") → Intermediate Superwall paywall → Stripe checkout sheet

**After (checkout-only mode):**
Web funnel ("Start your trial") → Brief loading spinner → Full-screen Stripe checkout

## When to Use This

This mode is designed for apps that:

- Run a **web-based acquisition funnel** (e.g., a landing page with "Start your free trial") that deeplinks into the app
- Use **Superwall's Stripe web checkout** for payment processing
- Want the in-app experience to feel like a seamless continuation of the web funnel, not a second paywall

**Typical scenario:** A user clicks "Start your trial" on your website, gets redirected into your iOS app, and should immediately see the Stripe checkout — not an intermediate Superwall paywall screen they've already conceptually passed.

## Setup

### Step 1: Configure Your Paywall in the Superwall Dashboard

Create a paywall and assign it to a placement (e.g., `"web_checkout"`). This paywall **must auto-trigger the purchase action on page load**. Add custom JavaScript in the Superwall paywall editor that immediately fires the checkout event when the page loads, for example:

```javascript
// In the paywall editor's custom JS section
window.addEventListener('load', function() {
  // Trigger the purchase action immediately — no user interaction needed
  Superwall.purchase();
});
```

This is what makes the Stripe checkout URL get generated as soon as the invisible webview finishes loading.

### Step 2: Call `openWebCheckout` in Your App

When the user arrives from your web funnel (e.g., via a deeplink or after onboarding), call:

```swift
Superwall.shared.openWebCheckout(
  forPlacement: "web_checkout",
  handler: handler
) {
  // This block runs after a successful purchase.
  // Unlock premium content, navigate to the main app, etc.
  unlockPremiumContent()
}
```

Or without a feature gate:

```swift
Superwall.shared.openWebCheckout(
  forPlacement: "web_checkout",
  handler: handler
)
```

### Step 3: Handle Errors (Optional but Recommended)

Use the `PaywallPresentationHandler` to handle errors — for example, if the webview fails to load or the placement isn't configured:

```swift
let handler = PaywallPresentationHandler()

handler.onError { error in
  // Webview failed to load or placement misconfigured.
  // Show a fallback UI or retry.
  print("Checkout failed: \(error.localizedDescription)")
}

handler.onDismiss { paywallInfo, result in
  switch result {
  case .purchased:
    // User completed the purchase
    navigateToHome()
  case .declined:
    // User dismissed the checkout without purchasing
    showRetryPrompt()
  case .restored:
    // User restored a previous purchase
    navigateToHome()
  }
}

Superwall.shared.openWebCheckout(
  forPlacement: "web_checkout",
  handler: handler
) {
  unlockPremiumContent()
}
```

## What the User Sees

1. **Loading spinner** — A native `UIActivityIndicatorView` on a plain background while the paywall webview loads invisibly behind the scenes.
2. **Full-screen Stripe checkout** — The checkout sheet appears full-screen (not as a half-sheet modal), since there's no visible paywall behind it.
3. **Done** — If they purchase, your feature block runs. If they cancel, everything dismisses automatically.

The entire experience feels like: tap a button → brief spinner → Stripe checkout. No intermediate paywall screen.

## How It Works Internally

1. `openWebCheckout()` calls `internallyRegister()` with `PaywallOverrides(checkoutOnly: true)`.
2. The `PaywallViewController` loads normally but with the webview hidden (`alpha = 0`) and UI elements (shimmer, refresh/exit buttons) suppressed. A native spinner is shown instead.
3. The webview loads and the paywall's JavaScript auto-fires the purchase event, which generates a Stripe checkout URL.
4. When `openPaymentSheet(url)` is called, the spinner is removed and the `CheckoutWebViewController` is presented as `.overFullScreen` (no animation, seamless transition).
5. When the checkout is dismissed:
   - **User cancelled:** The invisible paywall is auto-dismissed with `.declined`.
   - **User purchased:** The normal Superwall purchase/redemption flow continues.
6. If the webview fails to load, the error handler is called and everything is dismissed.

## File Changes

| File | Change | Reason |
|------|--------|--------|
| `PaywallOverrides.swift` | Added `checkoutOnly: Bool` property (default `false`) to all initializers | Opt-in flag without affecting existing behavior |
| `PublicPresentation.swift` | Added `openWebCheckout(forPlacement:)` methods; threaded `paywallOverrides` through `internallyRegister()` | Public API for developers + plumbing overrides to the presentation pipeline |
| `PaywallViewController.swift` | Added `isCheckoutOnly`, spinner helpers, modified `loadingStateDidChange`, `openPaymentSheet`, `handleWebViewFailure` | Invisible webview + spinner UX, fullscreen checkout presentation, auto-dismiss on close |
| `PaywallOverridesTests.swift` | 5 new unit tests | Verifies `checkoutOnly` defaults and initialization across all inits |
| `CHANGELOG.md` | Added entry | Documents the new feature for SDK consumers |

## Backward Compatibility

This feature is **fully opt-in and backward compatible**:

- `checkoutOnly` defaults to `false` in every `PaywallOverrides` initializer
- Existing `register()` calls are completely unaffected
- `openWebCheckout()` is a new additive method — no existing APIs are changed
- No dashboard changes are needed for apps not using this feature
