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
  /// See <doc:GameControllerSupport> for more information.
  ///
  /// - Parameters:
  ///   - gamepad: The extended Gamepad controller profile.
  ///   - element: The game controller element.
  @MainActor
  public func gamepadValueChanged(
    gamepad: GCExtendedGamepad,
    element: GCControllerElement
  ) {
    GameControllerManager.shared.gamepadValueChanged(gamepad: gamepad, element: element)
  }
}
