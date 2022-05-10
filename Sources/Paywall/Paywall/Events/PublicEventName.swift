//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/04/2022.
//

import Foundation

public extension Paywall {
  /// Analytical events that are automatically tracked by Superwall.
  ///
  /// These events are tracked internally by the SDK and sent to the delegate method ``Paywall/PaywallDelegate/trackAnalyticsEvent(withName:params:)``.
  enum EventName: String {
    case firstSeen = "first_seen"
    case appOpen = "app_open"
    case appLaunch = "app_launch"
    case appInstall = "app_install"
    case sessionStart = "session_start"
    case appClose = "app_close"
    case triggerFire = "trigger_fire"
    case paywallOpen = "paywall_open"
    case paywallClose = "paywall_close"
    case transactionStart = "transaction_start"
    case transactionFail = "transaction_fail"
    case transactionAbandon = "transaction_abandon"
    case transactionComplete = "transaction_complete"
    case subscriptionStart = "subscription_start"
    case freeTrialStart = "freeTrial_start"
    case transactionRestore = "transaction_restore"
    case nonRecurringProductPurchase = "nonRecurringProduct_purchase"
    case paywallResponseLoadStart = "paywallResponseLoad_start"
    case paywallResponseLoadNotFound = "paywallResponseLoad_notFound"
    case paywallResponseLoadFail = "paywallResponseLoad_fail"
    case paywallResponseLoadComplete = "paywallResponseLoad_complete"
    case paywallWebviewLoadStart = "paywallWebviewLoad_start"
    case paywallWebviewLoadFail = "paywallWebviewLoad_fail"
    case paywallWebviewLoadComplete = "paywallWebviewLoad_complete"
    case paywallProductsLoadStart = "paywallProductsLoad_start"
    case paywallProductsLoadFail = "paywallProductsLoad_fail"
    case paywallProductsLoadComplete = "paywallProductsLoad_complete"
  }
}
