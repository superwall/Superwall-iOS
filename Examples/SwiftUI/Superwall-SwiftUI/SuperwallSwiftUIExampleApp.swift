//
//  SuperwallSwiftUIExampleApp.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI

@main
struct SuperwallSwiftUIExampleApp: App {
  @State private var isLoggedIn = false

  init() {
    SuperwallService.configure()
  }

  var body: some Scene {
    WindowGroup {
      WelcomeView(isLoggedIn: $isLoggedIn)
        .font(.rubik(.four))
        .onOpenURL { url in
          SuperwallService.handleDeepLink(url)
        }
        .onReceive(SuperwallService.shared.isLoggedIn) { isLoggedIn in
          self.isLoggedIn = isLoggedIn
        }
    }
  }
}
