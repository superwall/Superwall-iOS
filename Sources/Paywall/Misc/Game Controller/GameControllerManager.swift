//
//  GameControllerManager.swift
//  GameControllerExample
//
//  Created by Jake Mor on 10/5/21.
//

import Foundation
import GameController

// swiftlint:disable:next class_delegate_protocol
protocol GameControllerDelegate: NSObject {
	func gameControllerEventDidOccur(event: GameControllerEvent)
}

final class GameControllerManager: NSObject {
	static var shared = GameControllerManager()
	weak var delegate: GameControllerDelegate?

	func valueChanged(
    _ name: String,
    _ value: Float
  ) {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else {
        return
      }
			let event = GameControllerEvent(
        controllerElement: name,
        value: Double(value),
        x: 0,
        y: 0,
        directional: false
      )
			self.delegate?.gameControllerEventDidOccur(event: event)
		}
	}

	func valueChanged(
    _ name: String,
    _ x: Float,
    _ y: Float
  ) {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else {
        return
      }
			let event = GameControllerEvent(
        controllerElement: name,
        value: 0,
        x: Double(x),
        y: Double(y),
        directional: true
      )
			self.delegate?.gameControllerEventDidOccur(event: event)
		}
	}

  func gamepadValueChanged(
    gamepad: GCExtendedGamepad,
    element: GCControllerElement
  ) {
		guard Paywall.isGameControllerEnabled else {
      return
    }
    guard #available(iOS 13.0, *) else {
      Logger.debug(
        logLevel: .debug,
        scope: .gameControllerManager,
        message: "Unsupported OS",
        info: nil,
        error: nil
      )
      return
    }

    let name = element.buttonName(gamepad: gamepad)
    switch element {
    case gamepad.leftTrigger:
      self.valueChanged(name, gamepad.leftTrigger.value)
    case gamepad.leftShoulder:
      self.valueChanged(name, gamepad.leftShoulder.value)
    case gamepad.rightTrigger:
      self.valueChanged(name, gamepad.rightTrigger.value)
    case gamepad.rightShoulder:
      self.valueChanged(name, gamepad.rightShoulder.value)
    case gamepad.leftThumbstick:
      self.valueChanged(name, gamepad.leftThumbstick.xAxis.value, gamepad.leftThumbstick.yAxis.value)
    case gamepad.leftThumbstickButton:
      // swiftlint:disable:next force_unwrapping
      self.valueChanged(name, gamepad.leftThumbstickButton!.value)
    case gamepad.rightThumbstick:
      self.valueChanged(name, gamepad.rightThumbstick.xAxis.value, gamepad.rightThumbstick.yAxis.value)
    case gamepad.rightThumbstickButton:
      // swiftlint:disable:next force_unwrapping
      self.valueChanged(name, gamepad.rightThumbstickButton!.value)
    case gamepad.dpad:
      self.valueChanged(name, gamepad.dpad.xAxis.value, gamepad.dpad.yAxis.value)
    case gamepad.dpad.down:
      self.valueChanged(name, gamepad.dpad.down.value)
    case gamepad.dpad.right:
      self.valueChanged(name, gamepad.dpad.right.value)
    case gamepad.dpad.up:
      self.valueChanged(name, gamepad.dpad.up.value)
    case gamepad.dpad.left:
      self.valueChanged(name, gamepad.dpad.left.value)
    case gamepad.buttonA:
      self.valueChanged(name, gamepad.buttonA.value)
    case gamepad.buttonB:
      self.valueChanged(name, gamepad.buttonB.value)
    case gamepad.buttonX:
      self.valueChanged(name, gamepad.buttonX.value)
    case gamepad.buttonY:
      self.valueChanged(name, gamepad.buttonY.value)
    case gamepad.buttonMenu:
      self.valueChanged(name, gamepad.buttonMenu.value)
    case gamepad.buttonOptions:
      // swiftlint:disable:next force_unwrapping
      self.valueChanged(name, gamepad.buttonOptions!.value)
    default:
      Logger.debug(
        logLevel: .debug,
        scope: .gameControllerManager,
        message: "Unrecognized Button",
        info: ["button": element],
        error: nil
      )
    }
	}
}

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
