//
//  File.swift
//  
//
//  Created by Jake Mor on 8/3/22.
//

import Foundation
import UIKit

extension UIApplication {
  var activeWindow: UIWindow? {
    guard let sharedApplication = UIApplication.sharedApplication else {
      return nil
    }
    // First, try to find a key window in the foreground active scene
    if let windowScene = sharedApplication.connectedScenes
      .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
      return windowScene.windows.first { $0.isKeyWindow } ?? windowScene.windows.first
    }

    // Then try to find a key window in the foreground inactive scene
    if let windowScene = sharedApplication.connectedScenes
      .first(where: { $0.activationState == .foregroundInactive }) as? UIWindowScene {
      return windowScene.windows.first { $0.isKeyWindow } ?? windowScene.windows.first
    }

    // Fallback: search across all scenes for a key window
    let windows = sharedApplication.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
    return windows.first { $0.isKeyWindow } ?? windows.first
  }

  /// The scene behind ``activeWindow``, using the same activation-state priority.
  ///
  /// Preferred over the window for trait observation: a window's
  /// `overrideUserInterfaceStyle` doesn't propagate up to its scene, so the scene's
  /// `userInterfaceStyle` follows the system the way `UIScreen.main` does. It also
  /// outlives the individual windows it hosts.
  var activeWindowScene: UIWindowScene? {
    guard let sharedApplication = UIApplication.sharedApplication else {
      return nil
    }
    if let windowScene = sharedApplication.connectedScenes
      .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
      return windowScene
    }
    if let windowScene = sharedApplication.connectedScenes
      .first(where: { $0.activationState == .foregroundInactive }) as? UIWindowScene {
      return windowScene
    }
    return sharedApplication.connectedScenes.compactMap { $0 as? UIWindowScene }.first
  }
}
