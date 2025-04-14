//
//  Delegate.swift
//  Superwall-SwiftUI
//
//  Created by Yusuf Tör on 01/04/2025.
//

import Foundation
import RevenueCat
import SuperwallKit

// MARK: - Option 1: Delegate when using a Purchase Controller with StoreKit

final class Delegate: SuperwallDelegate {
  let purchaseController: SWPurchaseController

  init(purchaseController: SWPurchaseController) {
    self.purchaseController = purchaseController
  }

  func didRedeemLink(result: RedemptionResult) {
    Task {
      await purchaseController.syncSubscriptionStatus()
    }
  }
}

// MARK: - Option 2: Delegate when using a Purchase Controller with RevenueCat
/*
final class Delegate: SuperwallDelegate {
  // The user tapped on a deep link to redeem a code
  func willRedeemLink() {
    print("[!] willRedeemLink")
    // Optionally show a loading indicator here
  }

  // Superwall received a redemption result and validated the purchase with Stripe.
  func didRedeemLink(result: RedemptionResult) {
    print("[!] didRedeemLink", result)
    // Send Stripe IDs to RevenueCat to link purchases to the customer

    // Get a list of subscription ids tied to the customer.
    guard let stripeSubscriptionIds = result.stripeSubscriptionIds else { return }
    guard let url = URL(string: "https://api.revenuecat.com/v1/receipts") else { return }

    let revenueCatStripePublicAPIKey = "strp....." // replace with your RevenueCat Stripe Public API Key
    let appUserId = Purchases.shared.appUserID

    // In the background...
    Task.detached {
      await withTaskGroup(of: Void.self) { group in
        // For each subscription id, link it to the user in RevenueCat
        for stripeSubscriptionId in stripeSubscriptionIds {
          group.addTask {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("stripe", forHTTPHeaderField: "X-Platform")
            request.setValue("Bearer \(revenueCatStripePublicAPIKey)", forHTTPHeaderField: "Authorization")

            do {
              request.httpBody = try JSONEncoder().encode([
                "app_user_id": appUserId,
                "fetch_token": stripeSubscriptionId
              ])

              let (data, _) = try await URLSession.shared.data(for: request)
              let json = try JSONSerialization.jsonObject(with: data, options: [])
              print("[!] Success: linked \(stripeSubscriptionId) to user \(appUserId)", json)
            } catch {
              print("[!] Error: unable to link \(stripeSubscriptionId) to user \(appUserId)", error)
            }
          }
        }
      }

      /// After all network calls complete, invalidate the cache without switching to the main thread.
      Purchases.shared.getCustomerInfo(fetchPolicy: .fetchCurrent) { customerInfo, error in
        /// If you're using `Purchases.shared.customerInfoStream`, or keeping Superwall Entitlements in sync
        /// via RevenueCat's `PurchasesDelegate` methods, you don't need to do anything here. Those methods will be
        /// called automatically when this call fetches the most up to customer info, ignoring any local caches.

        /// Otherwise, if you're manually calling `Purchases.shared.getCustomerInfo`  to keep Superwall's entitlements
        /// in sync, you should use the newly updated customer info here to do so.
      }

      /// You could always access web entitlements here as well
      /// `let webEntitlements = Superwall.shared.entitlements.web`

      // After all network calls complete...
      await MainActor.run {
        // Perform UI updates on the main thread, like letting the user know their subscription was redeemed
      }
    }
  }
}
*/
