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
}
