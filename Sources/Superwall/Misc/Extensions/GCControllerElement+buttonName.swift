//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/09/2022.
//

import GameController

extension GCControllerElement {
  // the identifier of this gamecontroller element that is accepted by the paywall javascript event listeners
  @available(iOS 13, macOS 10.15, *)
  func buttonName(gamepad: GCExtendedGamepad) -> String {
    switch self {
    case gamepad.leftTrigger:
      return "L2 Button"
    case gamepad.leftShoulder:
      return "L1 Button"
    case gamepad.rightTrigger:
      return "R2 Button"
    case gamepad.rightShoulder:
      return "R1 Button"
    case gamepad.leftThumbstick:
      return "Left Thumbstick"
    case gamepad.leftThumbstickButton:
      return "Left Thumbstick Button"
    case gamepad.rightThumbstick:
      return "Right Thumbstick"
    case gamepad.rightThumbstickButton:
      return "Right Thumbstick Button"
    case gamepad.dpad:
      return "Direction Pad"
    case gamepad.dpad.down:
      return "Direction Pad"
    case gamepad.dpad.right:
      return "Direction Pad"
    case gamepad.dpad.up:
      return "Direction Pad"
    case gamepad.dpad.left:
      return "Direction Pad"
    case gamepad.buttonA:
      return "A Button"
    case gamepad.buttonB:
      return "B Button"
    case gamepad.buttonX:
      return "X Button"
    case gamepad.buttonY:
      return "Y Button"
    case gamepad.buttonMenu:
      return "Menu Button"
    case gamepad.buttonOptions:
      return "Options Button"
    default:
      // Logger.debug(logLevel: .debug, scope: .gameControllerManager, message: "Unrecognized Button", info: ["button": element], error: nil)
      return "Unknown Button"
    }
  }
}
