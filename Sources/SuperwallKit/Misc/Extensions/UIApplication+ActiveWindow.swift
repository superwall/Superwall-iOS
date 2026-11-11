//
//  File.swift
//
//
//  Created by Jake Mor on 8/3/22.
//

#if !os(macOS) && !os(watchOS)
import Foundation
import UIKit

/// What's needed to decide which scene the user is working in.
@MainActor
protocol ForegroundSceneCandidate {
  var activationState: UIScene.ActivationState { get }

  /// Whether the scene looks active, which only the scene with focus does.
  ///
  /// An iPad or Mac Catalyst app can have several windows on screen at once, all of them
  /// `foregroundActive` and each with its own key window, so neither says which one the
  /// user is working in.
  var hasActiveAppearance: Bool { get }
}

extension UIWindowScene: ForegroundSceneCandidate {
  var hasActiveAppearance: Bool {
    return traitCollection.activeAppearance == .active
  }
}

extension Sequence where Element: ForegroundSceneCandidate {
  /// The scene the user is working in: an active one before an inactive one, and among
  /// those the one with focus. `nil` when no scene is in the foreground.
  @MainActor
  func foregroundScene() -> Element? {
    let states: [UIScene.ActivationState] = [.foregroundActive, .foregroundInactive]
    for state in states {
      let scenes = filter { $0.activationState == state }
      if let scene = scenes.first(where: { $0.hasActiveAppearance }) ?? scenes.first {
        return scene
      }
    }
    return nil
  }
}

extension UIApplication {
  var activeWindow: UIWindow? {
    guard let sharedApplication = UIApplication.sharedApplication else {
      return nil
    }
    let windowScenes = sharedApplication.connectedScenes.compactMap { $0 as? UIWindowScene }

    if let windowScene = windowScenes.foregroundScene() {
      return windowScene.keyWindow ?? windowScene.windows.first
    }

    // Fallback: search across all scenes for a key window
    let windows = windowScenes.flatMap { $0.windows }
    return windows.first { $0.isKeyWindow } ?? windows.first
  }

  /// The scene behind ``activeWindow``, chosen the same way.
  ///
  /// Preferred over the window for trait observation: a window's
  /// `overrideUserInterfaceStyle` doesn't propagate up to its scene, so the scene's
  /// `userInterfaceStyle` follows the system the way `UIScreen.main` does. It also
  /// outlives the individual windows it hosts.
  var activeWindowScene: UIWindowScene? {
    guard let sharedApplication = UIApplication.sharedApplication else {
      return nil
    }
    let windowScenes = sharedApplication.connectedScenes.compactMap { $0 as? UIWindowScene }
    return windowScenes.foregroundScene() ?? windowScenes.first
  }
}
#endif
