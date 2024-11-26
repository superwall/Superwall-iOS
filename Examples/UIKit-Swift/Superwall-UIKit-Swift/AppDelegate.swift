//
//  AppDelegate.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

import UIKit
import SuperwallKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // MARK: Configure Superwall
    #warning("Replace the API key with your own.")
    Superwall.configure(apiKey: "pk_e361c8a9662281f4249f2fa11d1a63854615fa80e15e7a4d")
    Superwall.shared.delegate = self
    return true
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}

extension AppDelegate: SuperwallDelegate {
  func entitlementStatusDidChange(to newValue: EntitlementStatus) {
    print("*** ENTITLEMENTS DID CHANGE to", newValue.description)
  }
}
