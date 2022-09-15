//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/04/2022.
//

import Foundation

public extension Paywall {
  @available(*, unavailable, renamed: "SuperwallEvent")
  enum EventName: String {
    case fakeCase = "fake"
  }
}

/// Analytical events that are automatically tracked by Superwall.
///
/// These events are tracked internally by the SDK and sent to the delegate method ``Paywall/PaywallDelegate/trackAnalyticsEvent(withName:params:)``.
public enum SuperwallEvent: String {
  /// When the user is first seen in the app, regardless of whether ``Paywall/Paywall/identify(userId:)`` has been called.
  case firstSeen = "first_seen"

  /// Anytime the app enters the foreground
  case appOpen = "app_open"

  /// When the app is launched from a cold start
  ///
  /// The raw value of this event can be added to a campaign to trigger a paywall.
  case appLaunch = "app_launch"

  /// When the SDK is configured for the first time, or directly after calling ``Paywall/Paywall/reset()``.
  ///
  /// The raw value of this event can be added to a campaign to trigger a paywall.
  case appInstall = "app_install"

  /// When the app is opened at least an hour since last  ``SuperwallEvent/appClose``.
  ///
  /// The raw value of this event can be added to a campaign to trigger a paywall.
  case sessionStart = "session_start"

  /// Anytime the app leaves the foreground.
  case appClose = "app_close"

  /// When a user opens the app via a deep link.
  ///
  /// The raw value of this event can be added to a campaign to trigger a paywall.
  case deepLink = "deepLink_open"

  /// When a trigger is fired.
  case triggerFire = "trigger_fire"

  /// When a paywall is opened.
  case paywallOpen = "paywall_open"

  /// When a paywall is closed.
  case paywallClose = "paywall_close"

  /// When the payment sheet is displayed to the user.
  case transactionStart = "transaction_start"

  /// When the payment sheet fails to complete a transaction (ignores user canceling the transaction).
  case transactionFail = "transaction_fail"

  /// When the user cancels a transaction.
  case transactionAbandon = "transaction_abandon"

  /// When the user completes checkout in the payment sheet and any product was purchased.
  case transactionComplete = "transaction_complete"

  /// When the user successfully completes a transaction for a subscription product with no introductory offers.
  case subscriptionStart = "subscription_start"

  /// When the user successfully completes a transaction for a subscription product with an introductory offer.
  case freeTrialStart = "freeTrial_start"

  /// When the user successfully restores their purchases.
  case transactionRestore = "transaction_restore"

  /// When the default paywall is presented using ``Paywall/Paywall/present(onPresent:onDismiss:onFail:)``.
  case manualPresent = "manual_present"

  /// When the user attributes are set.
  case userAttributes = "user_attributes"

  /// When the user purchased a non recurring product.
  case nonRecurringProductPurchase = "nonRecurringProduct_purchase"

  /// When a paywall's request to Superwall's servers has started.
  case paywallResponseLoadStart = "paywallResponseLoad_start"

  /// When a paywall's request to Superwall's servers returned a 404 error.
  case paywallResponseLoadNotFound = "paywallResponseLoad_notFound"

  /// When a paywall's request to Superwall's servers produced an error.
  case paywallResponseLoadFail = "paywallResponseLoad_fail"

  /// When a paywall's request to Superwall's servers is complete.
  case paywallResponseLoadComplete = "paywallResponseLoad_complete"

  /// When a paywall's website begins to load.
  case paywallWebviewLoadStart = "paywallWebviewLoad_start"

  /// When a paywall's website fails to load.
  case paywallWebviewLoadFail = "paywallWebviewLoad_fail"

  /// When a paywall's website completes loading.
  case paywallWebviewLoadComplete = "paywallWebviewLoad_complete"

  /// When the loading of a paywall's website times out.
  case paywallWebviewLoadTimeout = "paywallWebviewLoad_timeout"

  /// When the request to load the paywall's products started.
  case paywallProductsLoadStart = "paywallProductsLoad_start"

  /// When the request to load the paywall's products failed.
  case paywallProductsLoadFail = "paywallProductsLoad_fail"

  /// /// When the request to load the paywall's products completed.
  case paywallProductsLoadComplete = "paywallProductsLoad_complete"

  internal var canImplicitlyTriggerPaywall: Bool {
    switch self {
    case .appInstall,
      .sessionStart,
      .appLaunch,
      .deepLink:
      return true
    default:
      return false
    }
  }
}
