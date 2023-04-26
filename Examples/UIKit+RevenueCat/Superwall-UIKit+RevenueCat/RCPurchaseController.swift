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
  // Keeps Superwall's susbcription status up to date with RevenueCat's
  func syncSubscriptionStatus() {
    Purchases.shared.invalidateCustomerInfoCache()
    Task {
      for await customerInfo in Purchases.shared.customerInfoStream {
        // this gets called whenever new CustomerInfo is available
        let hasActiveSubscription = RCPurchaseController.hasActiveSubscription(customerInfo: customerInfo)
        if hasActiveSubscription {
          Superwall.shared.subscriptionStatus = .active
        } else {
          Superwall.shared.subscriptionStatus = .inactive
        }
      }
    }
  }

  // Logic for if a subscription is active
  private static func hasActiveSubscription(customerInfo: CustomerInfo) -> Bool {
    // A subscription is ACTIVE if it has active entitlements
    // More info -> https://www.revenuecat.com/docs/entitlements#entitlements
    return !customerInfo.entitlements.active.isEmpty
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
  /// Makes a restore with RevenueCat and returns true if the restore was successful.
  /// This gets called when someone tries to restore purchases on one of your paywalls.
  func restorePurchases() async -> Bool {
    do {
      let customerInfo = try await Purchases.shared.restorePurchases()
      return RCPurchaseController.hasActiveSubscription(customerInfo: customerInfo)
    } catch {
      print("restore failed")
      return false
    }
  }
}
