# Game Controller Support

Sending values from the game controller to the SDK

## Overview

SuperwallKit supports Game Controller input.

To forward events to your paywall, simply call ``Superwall/gamepadValueChanged(gamepad:element:)`` from your own gamepad's valueChanged handler:

```swift
controller.extendedGamepad?.valueChangedHandler = { gamepad, element in
  // Send values to Superwall
  Superwall.shared.gamepadValueChanged(gamepad: gamepad, element: element)
                                                   
  // ... rest of your code
}
```
