//
//  PurchaseControllerEntitlementsApp.swift
//  PurchaseController + Entitlements
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI
import Combine
import SuperwallKit
import RevenueCat
import StoreKit

@main
struct PurchaseControllerEntitlementsApp: App {
  @State private var isLoggedIn = false
  private var isPreviouslyLoggedIn = CurrentValueSubject<Bool, Never>(false)

  init() {
    #warning("For your own app you will need to use your own API key, available from the Superwall Dashboard")

    // MARK: Step 1 - Create your Purchase Controller
    /// Create an `RCPurchaseController()` wherever Superwall and RevenueCat are being initialized.
    let purchaseController = RCPurchaseController()

    // MARK: Step 2 - Configure Superwall
    /// Always configure Superwall first. Pass in the `purchaseController` you just created.
    Superwall.configure(
      apiKey: "pk_e361c8a9662281f4249f2fa11d1a63854615fa80e15e7a4d",
      purchaseController: purchaseController
    )

    // MARK: Step 3 – Configure RevenueCat
    /// Always configure RevenueCat after Superwall
    Purchases.configure(with:
      .builder(withAPIKey: "appl_PpUWCgFONlxwztRfNgEdvyGHiAG")
      .build()
    )

    // MARK: Step 4 – Sync Entitlements
    /// Keep Superwall's entitlements up-to-date with RevenueCat's.
    purchaseController.syncEntitlements()

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
