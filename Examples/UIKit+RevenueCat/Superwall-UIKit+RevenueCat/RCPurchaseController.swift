// swiftlint:disable all
//
//  RCPurchaseController.swift
//  Superwall-UIKit+RevenueCat
//
//  Created by Jake Mor on 4/26/23.
//

import SuperwallKit
import StoreKit
import RevenueCat
import Combine

enum PurchasingError: Error {
  case productNotFound
}

// MARK: Quickstart (v3.0.0+)
/// 1. Copy this file into your app
/// 2. Create an `RCPurchaseController` wherever Superwall and RevenueCat are being initialized.
///   `let purchaseController = RCPurchaseController()`
/// 3. First, configure Superwall. Pass in the `purchaseController` you just created.
///   `Superwall.configure(apiKey: "superwall_api_key", purchaseController: purchaseController)`
/// 4. Second, configure RevenueCat.
///   `Purchases.configure(withAPIKey: "revenuecat_api_key")`
/// 5. Third, Keep Superwall's subscription status up-to-date with RevenueCat's.
///   `purchaseController.syncSubscriptionStatus()`
final class RCPurchaseController: PurchaseController {
  // MARK: Sync Subscription Status
  /// Makes sure that Superwall knows the customers subscription status by
  /// changing `Superwall.shared.subscriptionStatus`
  func syncSubscriptionStatus() {
    assert(Purchases.isConfigured, "You must configure RevenueCat before calling this method.")
    Task {
      for await customerInfo in Purchases.shared.customerInfoStream {
        // Gets called whenever new CustomerInfo is available
        let hasActiveSubscription = !customerInfo.entitlements.activeInCurrentEnvironment.isEmpty // Why? -> https://www.revenuecat.com/docs/entitlements#entitlements
        if hasActiveSubscription {
          Superwall.shared.subscriptionStatus = .active
        } else {
          Superwall.shared.subscriptionStatus = .inactive
        }
      }
    }
  }

  // MARK: Handle Purchases
  /// Makes a purchase with RevenueCat and returns its result. This gets called when
  /// someone tries to purchase a product on one of your paywalls.
  func purchase(product: SKProduct) async -> PurchaseResult {
    do {
      guard let storeProduct = await Purchases.shared.products([product.productIdentifier]).first else {
        throw PurchasingError.productNotFound
      }
      
      let purchaseDate = Date()
      let revenueCatResult = try await Purchases.shared.purchase(product: storeProduct)
      if revenueCatResult.userCancelled {
        return .cancelled
      } else {
        return .purchased
      }
    } catch let error as ErrorCode {
      if error == .paymentPendingError {
        return .pending
      } else {
        return .failed(error)
      }
    } catch {
      return .failed(error)
    }
  }

  // MARK: Handle Restores
  /// Makes a restore with RevenueCat and returns `.restored`, unless an error is thrown.
  /// This gets called when someone tries to restore purchases on one of your paywalls.
  func restorePurchases() async -> RestorationResult {
    do {
      _ = try await Purchases.shared.restorePurchases()
      return .restored
    } catch let error {
      return .failed(error)
    }
  }
}
