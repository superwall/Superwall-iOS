//
//  SuperwallSwiftUIExampleApp.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI

@main
struct SuperwallSwiftUIExampleApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      WelcomeView()
        .font(.rubik(.four))
        .onOpenURL { url in
          PaywallService.trackDeepLink(url: url)
        }
    }
  }
}
