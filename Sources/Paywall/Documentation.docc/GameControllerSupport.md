# Game Controller Support

Sending values from the game controller to the SDK

## Overview

The Paywall SDK supports Game Controller input.

To forward events to your web paywall, simply call `gamepadValueChanged(gamepad:element:)` from your own gamepad's valueChanged handler:

```swift
controller.extendedGamepad?.valueChangedHandler = { gamepad, element in
  // send values to Paywall
  Paywall.gamepadValueChanged(gamepad: gamepad, element: element)
                                                   
  // ... rest of your code
}
```
