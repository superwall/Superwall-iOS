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

  func didRedeemCode(result: RedemptionResult) {
    Task {
      await purchaseController.syncSubscriptionStatus()
    }
  }
}

// MARK: - Option 2: Delegate when using a Purchase Controller with RevenueCat
/*
final class Delegate: SuperwallDelegate {
  func didRedeemCode(result: RedemptionResult) {
    guard let stripeSubscriptionIds = result.stripeSubscriptionIds else {
      return
    }

    // TODO: Mention this has to be the Stripe one in the docs
    let revenueCatStripePublicAPIKey = "strp_pfIhWPVBApdRldicuzPVpJUWTgA"
    let appUserId = Purchases.shared.appUserID

    guard let url = URL(string: "https://api.revenuecat.com/v1/receipts") else {
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "accept")
    request.addValue("stripe", forHTTPHeaderField: "X-Platform")
    request.addValue("Bearer \(revenueCatStripePublicAPIKey)", forHTTPHeaderField: "Authorization")

    for stripeSubscriptionId in stripeSubscriptionIds {
      let requestBody: [String: String] = [
        "app_user_id": appUserId,
        "fetch_token": stripeSubscriptionId
      ]

      request.httpBody = try? JSONEncoder().encode(requestBody)

      let task = URLSession.shared.dataTask(with: request)
      task.resume()
    }
  }
}
*/
