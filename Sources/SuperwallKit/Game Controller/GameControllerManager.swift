//
//  GameControllerManager.swift
//  GameControllerExample
//
//  Created by Jake Mor on 10/5/21.
//
// swiftlint:disable force_unwrapping

import Foundation
import GameController

// swiftlint:disable:next class_delegate_protocol
protocol GameControllerDelegate: NSObject {
	func gameControllerEventDidOccur(event: GameControllerEvent)
}

@MainActor
final class GameControllerManager: NSObject {
	static let shared = GameControllerManager()
	weak var delegate: GameControllerDelegate?

  func setDelegate(_ delegate: GameControllerDelegate) {
    guard Superwall.shared.options.isGameControllerEnabled else {
      return
    }
    self.delegate = delegate
  }

  func clearDelegate(_ delegate: PaywallViewController?) {
    guard
      Superwall.shared.options.isGameControllerEnabled,
      self.delegate == delegate
    else {
      return
    }
    self.delegate = nil
  }

	func valueChanged(
    _ name: String,
    _ value: Float
  ) {
    let event = GameControllerEvent(
      controllerElement: name,
      value: Double(value),
      x: 0,
      y: 0,
      directional: false
    )
    self.delegate?.gameControllerEventDidOccur(event: event)
	}

	func valueChanged(
    _ name: String,
    _ x: Float,
    _ y: Float
  ) {
    let event = GameControllerEvent(
      controllerElement: name,
      value: 0,
      x: Double(x),
      y: Double(y),
      directional: true
    )
    self.delegate?.gameControllerEventDidOccur(event: event)
	}

  func gamepadValueChanged(
    gamepad: GCExtendedGamepad,
    element: GCControllerElement
  ) {
    guard Superwall.shared.options.isGameControllerEnabled else {
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
      self.valueChanged(name, gamepad.leftThumbstickButton!.value)
    case gamepad.rightThumbstick:
      self.valueChanged(name, gamepad.rightThumbstick.xAxis.value, gamepad.rightThumbstick.yAxis.value)
    case gamepad.rightThumbstickButton:
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
