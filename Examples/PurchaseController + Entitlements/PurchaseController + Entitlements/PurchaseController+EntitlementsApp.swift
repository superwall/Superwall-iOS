//
//  PurchaseControllerEntitlementsApp.swift
//  PurchaseController + Entitlements
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI
import Combine
import SuperwallKit

@main
struct PurchaseControllerEntitlementsApp: App {
  @State private var isLoggedIn = false
  private var isPreviouslyLoggedIn = CurrentValueSubject<Bool, Never>(false)
  private let purchaseController = SWPurchaseController()

  init() {
    #warning("For your own app you will need to use your own API key, available from the Superwall Dashboard")
    let apiKey = "pk_e361c8a9662281f4249f2fa11d1a63854615fa80e15e7a4d"
    Superwall.configure(
      apiKey: apiKey,
      purchaseController: purchaseController
    )
    Task { [self] in
      await self.purchaseController.syncEntitlements()
    }
    isPreviouslyLoggedIn.send(Superwall.shared.isLoggedIn)
  }

  var body: some Scene {
    WindowGroup {
      WelcomeView(isLoggedIn: $isLoggedIn)
        .font(.rubik(.four))
        .onOpenURL { url in
          Superwall.shared.handleDeepLink(url)
        }
        .onReceive(isPreviouslyLoggedIn) { isLoggedIn in
          self.isLoggedIn = isLoggedIn
        }
    }
  }
}
