//
//  AppDelegate.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 10/03/2022.
//

import UIKit

final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    PaywallService.initPaywall()
    return true
  }
}
