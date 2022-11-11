//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/04/2022.
//

import Foundation

/// Analytical events that are automatically tracked by Superwall.
///
/// These events are tracked internally by the SDK and sent to the delegate method ``SuperwallDelegate/didTrackSuperwallEvent(_:)-6fcb9``.
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

  // TODO: Rename this
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

// MARK: - CustomStringConvertible
extension SuperwallEvent: CustomStringConvertible {
  /// The string value of the event name.
  public var description: String {
    return backingData.description
  }
}

// MARK: - Backing data
extension SuperwallEvent {
  struct BackingData {
    let objcEvent: SuperwallEventObjc
    let description: String

    init(
      objcEvent: SuperwallEventObjc,
      description: String
    ) {
      self.objcEvent = objcEvent
      self.description = description
    }
  }

  var backingData: BackingData {
    switch self {
    case .firstSeen:
      return .init(objcEvent: .firstSeen, description: "first_seen")
    case .appOpen:
      return .init(objcEvent: .appOpen, description: "app_open")
    case .appLaunch:
      return .init(objcEvent: .appLaunch, description: "app_launch")
    case .appInstall:
      return .init(objcEvent: .appInstall, description: "app_install")
    case .sessionStart:
      return .init(objcEvent: .sessionStart, description: "session_start")
    case .appClose:
      return .init(objcEvent: .appClose, description: "app_close")
    case .deepLink:
      return .init(objcEvent: .deepLink, description: "deepLink_open")
    case .triggerFire:
      return .init(objcEvent: .triggerFire, description: "trigger_fire")
    case .paywallOpen:
      return .init(objcEvent: .paywallOpen, description: "paywall_open")
    case .paywallClose:
      return .init(objcEvent: .paywallClose, description: "paywall_close")
    case .transactionStart:
      return .init(objcEvent: .transactionStart, description: "transaction_start")
    case .transactionFail:
      return .init(objcEvent: .transactionFail, description: "transaction_fail")
    case .transactionAbandon:
      return .init(objcEvent: .transactionAbandon, description: "transaction_abandon")
    case .transactionComplete:
      return .init(objcEvent: .transactionComplete, description: "transaction_complete")
    case .subscriptionStart:
      return .init(objcEvent: .subscriptionStart, description: "subscription_start")
    case .freeTrialStart:
      return .init(objcEvent: .freeTrialStart, description: "freeTrial_start")
    case .transactionRestore:
      return .init(objcEvent: .transactionRestore, description: "transaction_restore")
    case .userAttributes:
      return .init(objcEvent: .userAttributes, description: "user_attributes")
    case .nonRecurringProductPurchase:
      return .init(objcEvent: .nonRecurringProductPurchase, description: "nonRecurringProduct_purchase")
    case .paywallResponseLoadStart:
      return .init(objcEvent: .paywallResponseLoadStart, description: "paywallResponseLoad_start")
    case .paywallResponseLoadNotFound:
      return .init(objcEvent: .paywallResponseLoadNotFound, description: "paywallResponseLoad_notFound")
    case .paywallResponseLoadFail:
      return .init(objcEvent: .paywallResponseLoadFail, description: "paywallResponseLoad_fail")
    case .paywallResponseLoadComplete:
      return .init(objcEvent: .paywallResponseLoadComplete, description: "paywallResponseLoad_complete")
    case .paywallWebviewLoadStart:
      return .init(objcEvent: .paywallWebviewLoadStart, description: "paywallWebviewLoad_start")
    case .paywallWebviewLoadFail:
      return .init(objcEvent: .paywallWebviewLoadFail, description: "paywallWebviewLoad_fail")
    case .paywallWebviewLoadComplete:
      return .init(objcEvent: .paywallWebviewLoadComplete, description: "paywallWebviewLoad_complete")
    case .paywallWebviewLoadTimeout:
      return .init(objcEvent: .paywallWebviewLoadTimeout, description: "paywallWebviewLoad_timeout")
    case .paywallProductsLoadStart:
      return .init(objcEvent: .paywallProductsLoadStart, description: "paywallProductsLoad_start")
    case .paywallProductsLoadFail:
      return .init(objcEvent: .paywallProductsLoadFail, description: "paywallProductsLoad_fail")
    case .paywallProductsLoadComplete:
      return .init(objcEvent: .paywallProductsLoadComplete, description: "paywallProductsLoad_complete")
    }
  }
}


/*

 // MARK: - Objective-C compatible `SuperwallEvent`
 @objc(SWKSuperwallEvent)
 public enum SuperwallEventObjc: Int {
   case firstSeen
   case appOpen
   case appLaunch
   case appInstall
   case sessionStart
   case appClose
   case deepLink
   case triggerFire
   case paywallOpen
   case paywallClose
   case transactionStart
   case transactionFail
   case transactionAbandon
   case transactionComplete
   case subscriptionStart
   case freeTrialStart
   case transactionRestore
   case userAttributes
   case nonRecurringProductPurchase
   case paywallResponseLoadStart
   case paywallResponseLoadNotFound
   case paywallResponseLoadFail
   case paywallResponseLoadComplete
   case paywallWebviewLoadStart
   case paywallWebviewLoadFail
   case paywallWebviewLoadComplete
   case paywallWebviewLoadTimeout
   case paywallProductsLoadStart
   case paywallProductsLoadFail
   case paywallProductsLoadComplete

   public init(event: SuperwallEvent) {
     self = convert(event)
   }

   private func convert(_ event: SuperwallEvent) -> SuperwallEventObjc {
     switch event {
     case .firstSeen:
       return .firstSeen
     case .appOpen:
       return .appOpen
     case .appLaunch:
       return .appLaunch
     case .appInstall:
       return .appInstall
     case .sessionStart:
       return .sessionStart
     case .appClose:
       return .appClose
     case .deepLink(let url):
       return .deepLink
     case .triggerFire(let eventName, let result):
       return .triggerFire
     case .paywallOpen(let paywallInfo):
       return .paywallOpen
     case .paywallClose(let paywallInfo):
       return .paywallClose
     case .transactionStart(let product, let paywallInfo):
       return .transactionStart
     case .transactionFail(let error, let paywallInfo):
       return .transactionFail
     case .transactionAbandon(let product, let paywallInfo):

     case .transactionComplete(let transaction, let product, let paywallInfo):
       <#code#>
     case .subscriptionStart(let product, let paywallInfo):
       <#code#>
     case .freeTrialStart(let product, let paywallInfo):
       <#code#>
     case .transactionRestore(let paywallInfo):
       <#code#>
     case .userAttributes(let _):
       <#code#>
     case .nonRecurringProductPurchase(let product, let paywallInfo):
       <#code#>
     case .paywallResponseLoadStart(let triggeredEventName):
       <#code#>
     case .paywallResponseLoadNotFound(let triggeredEventName):
       <#code#>
     case .paywallResponseLoadFail(let triggeredEventName):
       <#code#>
     case .paywallResponseLoadComplete(let triggeredEventName, let paywallInfo):
       <#code#>
     case .paywallWebviewLoadStart(let paywallInfo):
       <#code#>
     case .paywallWebviewLoadFail(let paywallInfo):
       <#code#>
     case .paywallWebviewLoadComplete(let paywallInfo):
       <#code#>
     case .paywallWebviewLoadTimeout(let paywallInfo):
       <#code#>
     case .paywallProductsLoadStart(let triggeredEventName, let paywallInfo):
       <#code#>
     case .paywallProductsLoadFail(let triggeredEventName, let paywallInfo):
       <#code#>
     case .paywallProductsLoadComplete(let triggeredEventName):
       <#code#>
     }
   }
 }

 extension SuperwallEventObjc: RawRepresentable {
   public typealias RawValue = String

   public var rawValue: RawValue {
     switch self {
     case .appClose:
       return "app_close"
     case .appOpen:
       return "app_open"
     case .firstSeen:
       return "first_seen"
     case .appLaunch:
       return "app_launch"
     case .appInstall:
       return "app_install"
     case .sessionStart:
       return "session_start"
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
     case .transactionRestore:
       return "transaction_restore"
     case .subscriptionStart:
       return "subscription_start"
     case .freeTrialStart:
       return "freeTrial_start"
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

   public init?(rawValue: RawValue) {
     return nil
   }
 }

 */
