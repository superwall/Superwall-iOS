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

final class RCPurchaseController: PurchaseController {

  init(revenueCatAPIKey apiKey: String) {
    Superwall.onInitialized = { [weak self] in
      Purchases.configure(
        with: .init(withAPIKey: apiKey)
          .with(usesStoreKit2IfAvailable: false) // don't use StoreKit2
      )
      self?.syncSubscriptionStatus()
    }
  }

  // Keeps Superwall's susbcription status up to date with RevenueCat's
  func syncSubscriptionStatus() {
    Task {
      for await customerInfo in Purchases.shared.customerInfoStream {
        // gets called whenever new CustomerInfo is available
        // A subscription is ACTIVE if it has active entitlements
        // More info -> https://www.revenuecat.com/docs/entitlements#entitlements
        let hasActiveSubscription = !customerInfo.entitlements.active.isEmpty
        if hasActiveSubscription {
          Superwall.shared.subscriptionStatus = .active
        } else {
          Superwall.shared.subscriptionStatus = .inactive
        }
      }
    }
  }

  // MARK: Purchase
  /// Makes a purchase with RevenueCat and returns its result. This gets called when
  /// someone tries to purchase a product on one of your paywalls.
  func purchase(product: SKProduct) async -> PurchaseResult {
    do {
      let storeProduct = RevenueCat.StoreProduct(sk1Product: product)
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

  // MARK: Restore
  /// Makes a restore with RevenueCat and returns true, unless an error is thrown.
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
