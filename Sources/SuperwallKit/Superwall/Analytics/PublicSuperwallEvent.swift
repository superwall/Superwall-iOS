//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/04/2022.
//

import Foundation

/// Analytical events that are automatically tracked by Superwall.
///
/// These events are tracked internally by the SDK and sent to the delegate method ``SuperwallKit/SuperwallDelegate/trackAnalyticsEvent(withName:params:)``.
public enum SuperwallEvent {
  /// When the user is first seen in the app, regardless of whether the user is logged in or not.
  case firstSeen

  /// Anytime the app enters the foreground
  case appOpen

  /// When the app is launched from a cold start
  ///
  /// The raw value of this event can be added to a campaign to trigger a paywall.
  case appLaunch

  /// When the SDK is configured for the first time, or directly after calling ``Superwall/reset()``.
  ///
  /// The raw value of this event can be added to a campaign to trigger a paywall.
  case appInstall

  /// When the app is opened at least an hour since last  ``SuperwallEvent/appClose``.
  ///
  /// The raw value of this event can be added to a campaign to trigger a paywall.
  case sessionStart

  /// Anytime the app leaves the foreground.
  case appClose

  /// When a user opens the app via a deep link.
  ///
  /// The raw value of this event can be added to a campaign to trigger a paywall.
  case deepLink(url: URL)

  //TODO: Rename this
  /// When a trigger is fired.
  case triggerFire(eventName: String, result: TriggerResult)

  /// When a paywall is opened.
  case paywallOpen(paywallInfo: PaywallInfo)

  /// When a paywall is closed.
  case paywallClose(paywallInfo: PaywallInfo)

  /// When the payment sheet is displayed to the user.
  case transactionStart(product: Attributes, paywallInfo: PaywallInfo)

  /// When the payment sheet fails to complete a transaction (ignores user canceling the transaction).
  case transactionFail(error: TransactionError, paywallInfo: PaywallInfo)

  /// When the user cancels a transaction.
  case transactionAbandon(product: Attributes, paywallInfo: PaywallInfo)

  /// When the user completes checkout in the payment sheet and any product was purchased.
  case transactionComplete(transaction: TransactionModel, product: Attributes, paywallInfo: PaywallInfo)

  /// When the user successfully completes a transaction for a subscription product with no introductory offers.
  case subscriptionStart(product: Attributes, paywallInfo: PaywallInfo)

  /// When the user successfully completes a transaction for a subscription product with an introductory offer.
  case freeTrialStart(product: Attributes, paywallInfo: PaywallInfo)

  /// When the user successfully restores their purchases.
  case transactionRestore(paywallInfo: PaywallInfo)

  /// When the user attributes are set.
  case userAttributes(_ attributes: [String: Any])

  /// When the user purchased a non recurring product.
  case nonRecurringProductPurchase(product: Attributes, paywallInfo: PaywallInfo)

  /// When a paywall's request to Superwall's servers has started.
  case paywallResponseLoadStart(triggeredEventName: String?)

  /// When a paywall's request to Superwall's servers returned a 404 error.
  case paywallResponseLoadNotFound(triggeredEventName: String?)

  /// When a paywall's request to Superwall's servers produced an error.
  case paywallResponseLoadFail(triggeredEventName: String?)

  /// When a paywall's request to Superwall's servers is complete.
  case paywallResponseLoadComplete(triggeredEventName: String?, paywallInfo: PaywallInfo)

  /// When a paywall's website begins to load.
  case paywallWebviewLoadStart(paywallInfo: PaywallInfo)

  /// When a paywall's website fails to load.
  case paywallWebviewLoadFail(paywallInfo: PaywallInfo)

  /// When a paywall's website completes loading.
  case paywallWebviewLoadComplete(paywallInfo: PaywallInfo)

  /// When the loading of a paywall's website times out.
  case paywallWebviewLoadTimeout(paywallInfo: PaywallInfo)

  /// When the request to load the paywall's products started.
  case paywallProductsLoadStart(triggeredEventName: String?, paywallInfo: PaywallInfo)

  /// When the request to load the paywall's products failed.
  case paywallProductsLoadFail(triggeredEventName: String?, paywallInfo: PaywallInfo)

  /// When the request to load the paywall's products completed.
  case paywallProductsLoadComplete(triggeredEventName: String?)

  //TODO: Add public function that allows the user to convert event into a [String: Any]?
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
  

  public var name: String {
    switch self {
    case .firstSeen:
      return "first_seen"
    case .appOpen:
      return "app_open"
    case .appLaunch:
      return "app_launch"
    case .appInstall:
      return "app_install"
    case .sessionStart:
      return "session_start"
    case .appClose:
      return "app_close"
    case .deepLink:
      return "deepLink_open"
    case .triggerFire:
      return "trigger_fire"
    case .paywallOpen:
      return "paywall_open"
    case .paywallClose:
      return "paywall_close"
    case .transactionStart:
      return "transaction_start"
    case .transactionFail:
      return "transaction_fail"
    case .transactionAbandon:
      return "transaction_abandon"
    case .transactionComplete:
      return "transaction_complete"
    case .subscriptionStart:
      return "subscription_start"
    case .freeTrialStart:
      return "freeTrial_start"
    case .transactionRestore:
      return "transaction_restore"
    case .userAttributes:
      return "user_attributes"
    case .nonRecurringProductPurchase:
      return "nonRecurringProduct_purchase"
    case .paywallResponseLoadStart:
      return "paywallResponseLoad_start"
    case .paywallResponseLoadNotFound:
      return "paywallResponseLoad_notFound"
    case .paywallResponseLoadFail:
      return "paywallResponseLoad_fail"
    case .paywallResponseLoadComplete:
      return "paywallResponseLoad_complete"
    case .paywallWebviewLoadStart:
      return "paywallWebviewLoad_start"
    case .paywallWebviewLoadFail:
      return "paywallWebviewLoad_fail"
    case .paywallWebviewLoadComplete:
      return "paywallWebviewLoad_complete"
    case .paywallWebviewLoadTimeout:
      return "paywallWebviewLoad_timeout"
    case .paywallProductsLoadStart:
      return "paywallProductsLoad_start"
    case .paywallProductsLoadFail:
      return "paywallProductsLoad_fail"
    case .paywallProductsLoadComplete:
      return "paywallProductsLoad_complete"
    }
  }
}
