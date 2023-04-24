//
//  SceneDelegate.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

import UIKit
import SuperwallKit

// MARK: - In App Previews & Deep Links
/// Get in app previews working
/// Turn deep links into campaigns that open specific paywalls on launch

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  // For cold starts
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    for context in connectionOptions.urlContexts {
      Superwall.shared.handleDeepLink(context.url)
    }
  }

  // For when your app is already running
  func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts {
      Superwall.shared.handleDeepLink(context.url)
    }
  }
}
