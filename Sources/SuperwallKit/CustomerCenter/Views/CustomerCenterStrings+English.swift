//
//  CustomerCenterStrings+English.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation

/// Minimal string provider so logic/tests don't depend on bundles.
struct CustomerCenterStrings {
  var lookup: (String) -> String

  func string(_ key: String, _ args: CVarArg...) -> String {
    let format = lookup(key)
    return args.isEmpty ? format : String(format: format, arguments: args)
  }

  /// English literals matching Task 9's `Localizable.strings` keys.
  static let english = CustomerCenterStrings { key in englishStrings[key] ?? key }
}

/// English literals keyed by localization key. Extended in Task 9 with the remaining
/// Customer Center strings; this task only adds the keys `PurchasePresentationBuilder` uses.
let englishStrings: [String: String] = [
  "customer_center_renews_on_for": "Renews on %@ for %@",
  "customer_center_renews_on": "Renews on %@",
  "customer_center_expires_on": "Expires on %@",
  "customer_center_expired_on": "Expired on %@",
  "customer_center_free_trial_until": "Free trial until %@",
  "customer_center_billing_issue": "Billing issue – update your payment method to keep access",
  "customer_center_lifetime": "Lifetime access",
  "customer_center_revoked": "Refunded",
  "customer_center_purchased_on": "Purchased on %@",
  "customer_center_active_via_superwall": "Active",
  "customer_center_price_per_period": "%@ / %@",
  "customer_center_store_web": "Web",
  "customer_center_store_google_play": "Google Play",
  "customer_center_store_superwall": "Superwall",
  "customer_center_store_other": "Other"
]
