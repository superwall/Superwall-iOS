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

extension CustomerCenterStrings {
  /// Strings backed by the SDK's localized bundles, falling back to English, then the key.
  static func bundled(locale: Locale? = nil) -> CustomerCenterStrings {
    let bundle = LocalizationLogic.localizedBundle(locale)
    return CustomerCenterStrings { key in
      let value = bundle.localizedString(forKey: key, value: "", table: nil)
      if !value.isEmpty && value != key { return value }
      return englishStrings[key] ?? key
    }
  }
}

/// English literals keyed by localization key. Must match every `customer_center_` key in
/// `en.lproj/Localizable.strings`.
let englishStrings: [String: String] = [
  // Customer Center – screens
  "customer_center_management_title": "Manage your subscription",
  "customer_center_no_purchases_title": "No subscriptions found",
  "customer_center_no_purchases_subtitle": "We can check for previous purchases.",
  "customer_center_close": "Close",
  "customer_center_back": "Back",
  "customer_center_done": "Done",
  "customer_center_cancel": "Cancel",
  // Customer Center – paths
  "customer_center_path_restore": "Restore purchases",
  // The value and the key differ on purpose: the key tracks `PathType.manageSubscription`, while the
  // label says what the row does for the customer. In the default configuration this row carries the
  // cancellation survey and opens Apple's sheet, where cancelling is the primary action.
  "customer_center_path_manage_subscription": "Cancel subscription",
  "customer_center_path_refund": "Request a refund",
  "customer_center_path_change_plan": "Change plan",
  "customer_center_path_contact_support": "Contact support",
  // Customer Center – default survey
  "customer_center_survey_cancel_title": "Why are you cancelling?",
  "customer_center_survey_too_expensive": "Too expensive",
  "customer_center_survey_dont_use": "Don't use the app",
  "customer_center_survey_bought_by_mistake": "Bought by mistake",
  // Customer Center – purchase status
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
  "customer_center_expired": "Expired",
  "customer_center_purchase_date": "Purchase date",
  "customer_center_expiration_date": "Expiration date",
  // Customer Center – badges
  "customer_center_badge_active": "Active",
  "customer_center_badge_free_trial": "Free trial",
  "customer_center_badge_cancelled": "Cancelled",
  "customer_center_badge_billing_issue": "Billing issue",
  "customer_center_badge_expired": "Expired",
  "customer_center_badge_revoked": "Refunded",
  "customer_center_badge_lifetime": "Lifetime",
  // Customer Center – stores
  "customer_center_store_web": "Web",
  "customer_center_store_google_play": "Google Play",
  "customer_center_store_superwall": "Superwall",
  "customer_center_store_other": "Other",
  "customer_center_family_shared": "Shared through Family Sharing",
  // Customer Center – sections
  "customer_center_section_subscriptions": "Subscriptions",
  "customer_center_section_purchases": "Purchases",
  "customer_center_section_actions": "Actions",
  "customer_center_see_all_purchases": "See all purchases",
  "customer_center_purchase_history": "Purchase history",
  "customer_center_history_active": "Active subscriptions",
  "customer_center_history_expired": "Expired subscriptions",
  "customer_center_history_other": "Other purchases",
  "customer_center_account_details": "Account details",
  "customer_center_user_id": "User ID",
  "customer_center_copy": "Copy",
  "customer_center_copied": "Copied",
  "customer_center_original_download_date": "Original download date",
  "customer_center_transaction_id": "Transaction ID",
  "customer_center_product_id": "Product ID",
  "customer_center_store": "Store",
  "customer_center_sandbox": "Sandbox",
  "customer_center_offer": "Offer",
  // Customer Center – restore
  "customer_center_restoring": "Restoring…",
  "customer_center_restore_success_title": "Purchases restored",
  "customer_center_restore_success_message": "We restored your past purchases and applied them to your account.",
  "customer_center_restore_none_title": "No past purchases",
  "customer_center_restore_none_message": "We couldn't find any purchases for your account. If you think this "
    + "is an error, please contact support.",
  // Customer Center – refund
  "customer_center_refund_success": "Apple has received your refund request.",
  "customer_center_refund_error": "Something went wrong requesting a refund. Please try again.",
  // Customer Center – update warning
  "customer_center_update_title": "Update available",
  "customer_center_update_message": "Downloading the latest version of the app may help solve the problem.",
  "customer_center_update_action": "Update",
  "customer_center_update_continue": "Continue",
  // Customer Center – duplicate subscriptions
  "customer_center_duplicate_title": "You may have duplicate subscriptions",
  "customer_center_duplicate_message": "You might be subscribed both on the web and through the App Store. To "
    + "avoid being charged twice, cancel one of them.",
  // Customer Center – support
  "customer_center_support_subject": "Support request",
  "customer_center_support_body": "Please describe your issue or question.",
  "customer_center_no_mail_app": "No mail app is configured on this device. You can reach us at %@."
]
