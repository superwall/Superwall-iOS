//
//  SuperwallAdvancedApp.swift
//  SuperwallSwiftUIExample
//
//  Created by Yusuf Tör on 10/03/2022.
//

import SwiftUI
import Combine
import SuperwallKit
import RevenueCat

@main
struct SuperwallAdvancedApp: App {
  @State private var isLoggedIn = false
  private var isPreviouslyLoggedIn = CurrentValueSubject<Bool, Never>(false)
  var delegate: Delegate?

  init() {
    #warning("For your own app you will need to use your own API key, available from the Superwall Dashboard")
    let apiKey = "pk_e361c8a9662281f4249f2fa11d1a63854615fa80e15e7a4d"

    // MARK: - Option 1: Let Superwall handle everything
    Superwall.configure(apiKey: apiKey)
    
    // MARK: - Option 2: Use a Purchase Controller with StoreKit
    /*
    // Step 1 - Create your Purchase Controller
    let purchaseController = SWPurchaseController()

    // Step 2 - Configure Superwall
    Superwall.configure(
      apiKey: apiKey,
      purchaseController: purchaseController
    )

    // Step 3 - Optionally create and set a SuperwallDelegate.
    // Check out the Delegate class if you're using web paywalls.
    delegate = Delegate()
    Superwall.shared.delegate = delegate

    // Step 4 - Sync Subscription Status
    Task {
      await purchaseController.syncSubscriptionStatus()
    }
    */

    // MARK: - Option 3: Using a Purchase Controller with RevenueCat
    /*
    // Step 1 - Create your Purchase Controller
    /// Create an `RCPurchaseController()` wherever Superwall and RevenueCat are being initialized.
    let purchaseController = RCPurchaseController()

    // Step 2 - Configure Superwall
    /// Always configure Superwall first. Pass in the `purchaseController` you just created.
    Superwall.configure(
      apiKey: apiKey,
      purchaseController: purchaseController
    )

    // Step 3 - Optionally create and set a SuperwallDelegate.
    // Check out the Delegate class if you're using web paywalls.
    delegate = Delegate()
    Superwall.shared.delegate = delegate

    // Step 4 – Configure RevenueCat
    /// Always configure RevenueCat after Superwall
    Purchases.configure(with:
      .builder(withAPIKey: "appl_PpUWCgFONlxwztRfNgEdvyGHiAG")
      .build()
    )

    // Step 5 – Sync Subscription Status
    /// Keep Superwall's subscription status up-to-date with RevenueCat's.
    purchaseController.syncSubscriptionStatus()
    */

    isPreviouslyLoggedIn.send(Superwall.shared.isLoggedIn)
  }

  var body: some Scene {
    WindowGroup {
      WelcomeView(isLoggedIn: $isLoggedIn)
        .font(.rubik(.four))
        .onOpenURL { url in
          Superwall.handleDeepLink(url)
        }
        .onReceive(isPreviouslyLoggedIn) { isLoggedIn in
          self.isLoggedIn = isLoggedIn
        }
    }
  }
}
