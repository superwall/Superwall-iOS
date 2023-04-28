//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/09/2022.
//

import GameController

extension Superwall {
  /// Forwards Game controller events to the paywall.
  ///
  /// Call this in Gamepad's `valueChanged` function to forward game controller events to the paywall via `paywall.js`.
  ///
  /// See [Game Controller Support](https://docs.superwall.com/docs/game-controller-support) for more information.
  ///
  /// - Parameters:
  ///   - gamepad: The extended Gamepad controller profile.
  ///   - element: The game controller element.
  public func gamepadValueChanged(
    gamepad: GCExtendedGamepad,
    element: GCControllerElement
  ) {
    Task { @MainActor in
      GameControllerManager.shared.gamepadValueChanged(gamepad: gamepad, element: element)
    }
  }
}
