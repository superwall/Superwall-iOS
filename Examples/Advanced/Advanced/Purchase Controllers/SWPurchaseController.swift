//
//  SWPurchaseController.swift
//  Advanced
//
//  Created by Yusuf Tör on 13/12/2024.
//

import StoreKit
import SuperwallKit

// MARK: Quickstart (v3.0.0+)
/// 1. Copy this file into your app
/// 2. Create a `PurchaseController` wherever Superwall is being initialized.
///   `let purchaseController = SWPurchaseController()`
/// 3. Configure Superwall. Pass in the `purchaseController` you just created.
///   `Superwall.configure(apiKey: "superwall_api_key", purchaseController: purchaseController)`
/// 5. Then, keep Superwall's subscription status up-to-date with StoreKit's entitlements.
///   `purchaseController.syncSubscriptionStatus()`
final class SWPurchaseController: PurchaseController {
  // MARK: Sync Subscription Status
  /// Makes sure that Superwall knows the customer's subscription status by
  /// changing `Superwall.shared.subscriptionStatus`
  func syncSubscriptionStatus() async {
    var products: Set<String> = []
    for await verificationResult in Transaction.currentEntitlements {
      switch verificationResult {
      case .verified(let transaction):
        products.insert(transaction.productID)
      case .unverified:
        break
      }
    }

    let storeProducts = await Superwall.shared.products(for: products)
    let entitlements = Set(storeProducts.flatMap { $0.entitlements })

    await MainActor.run {
      Superwall.shared.subscriptionStatus = .active(entitlements)
    }
  }

  // MARK: Handle Purchases
  /// Makes a purchase with Superwall and returns its result after syncing subscription status. This gets called when
  /// someone tries to purchase a product on one of your paywalls.
  func purchase(product: StoreProduct) async -> PurchaseResult {
    let result = await Superwall.shared.purchase(product)
    await syncSubscriptionStatus()
    return result
  }

  // MARK: Handle Restores
  /// Makes a restore with Superwall and returns its result after syncing subscription status.
  /// This gets called when someone tries to restore purchases on one of your paywalls.
  func restorePurchases() async -> RestorationResult {
    let result = await Superwall.shared.restorePurchases()
    await syncSubscriptionStatus()
    return result
  }
}
