//
//  AppDelegate.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

import UIKit
import StoreKit


@available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
class StoreKit2TransactionListener {

  private(set) var taskHandle: Task<Void, Never>?

  func listenForTransactions() {
    self.taskHandle = Task { [weak self] in
      for await result in StoreKit.Transaction.updates {
        guard let self = self else {
          break
        }

        print("TRANSACTION HERE")
      }
    }
  }

  deinit {
    self.taskHandle?.cancel()
    self.taskHandle = nil
  }

}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
  var storekitlistener = StoreKit2TransactionListener()
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
   // storekitlistener.listenForTransactions()
    SuperwallService.configure()
    return true
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
  }
}
