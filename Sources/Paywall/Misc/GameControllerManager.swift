//
//  GameControllerManager.swift
//  GameControllerExample
//
//  Created by Jake Mor on 10/5/21.
//

import Foundation
import GameController

struct GameControllerEvent: Codable {
	var element: String
	var value: Double
	var x: Double
	var y: Double
	var isDirectional: Bool
}

internal protocol GameControllerDelegate: NSObject {
	func connectionStatusDidChange(isConnected: Bool)
	func gameControllerEventDidOccur(event: GameControllerEvent)
}

internal class GameControllerManager: NSObject {
	
	static var shared = GameControllerManager()
	weak var delegate: GameControllerDelegate? = nil
	
	func begin() {
		NotificationCenter.default.addObserver(self, selector: #selector(controllerDidConnect), name: NSNotification.Name.GCControllerDidConnect, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(controllerDidDisconnect), name: NSNotification.Name.GCControllerDidDisconnect, object: nil)

	}
	
	func valueChanged(_ name: String, _ value: Float) {
		
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			let e = GameControllerEvent(element: name, value: Double(value), x: 0, y: 0, isDirectional: false)
			self.delegate?.gameControllerEventDidOccur(event: e)
		}
		
		
	}
	
	func valueChanged(_ name: String, _ x: Float, _ y: Float) {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			let e = GameControllerEvent(element: name, value: 0, x: Double(x), y: Double(y), isDirectional: true)
			self.delegate?.gameControllerEventDidOccur(event: e)
		}
	}
	
	@objc func controllerDidConnect() {
		delegate?.connectionStatusDidChange(isConnected: true)
		for controller in GCController.controllers() {
			controller.extendedGamepad?.valueChangedHandler = { [weak self] (gamepad: GCExtendedGamepad, element: GCControllerElement) in
				guard let self = self else { return }
				
				let name = element.localizedName ?? "unknown"
				if #available(iOS 13.0, *) {
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
							self.valueChanged(name, gamepad.buttonOptions!.value)
						default:
							Logger.superwallDebug("Warning: unrecognized button:", element)
							
					}
				} else {
					Logger.superwallDebug("Warning: Unsupported OS for Game Controller input")
				}
			}
		}
	}
	
	@objc func controllerDidDisconnect() {
		delegate?.connectionStatusDidChange(isConnected: false)
	}
	
}

