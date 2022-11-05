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
}
    
extension SuperwallEvent: CustomStringConvertible {
    public var params: [String: Any]? {
        return backingData.params
    }
    
    public var description: String {
        return backingData.description
    }
}

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
        self = event.backingData.objcEvent
    }
}

// MARK: - Backing data

extension SuperwallEvent {
    struct BackingData {
        let objcEvent: SuperwallEventObjc
        let params: [String: Any]?
        let description: String
        
        init(objcEvent: SuperwallEventObjc, params: [String : Any]? = nil, description: String) {
            self.objcEvent = objcEvent
            self.params = params
            self.description = description
        }
    }
    
    var backingData: BackingData {
        #warning("TODO")
        return .init(objcEvent: .firstSeen, description: "first_seen")
//        switch self {
//        case .firstSeen:
//          return .init(objcEvent: .firstSeen, description: "first_seen")
//        case .appOpen:
//          return .init(objcEvent: .appOpen, description: "app_open")
//        case .appLaunch:
//          return .init(objcEvent: .appLaunch, description: "app_launch")
//        case .appInstall:
//          return .init(objcEvent: .appInstall, description: "app_install")
//        case .sessionStart:
//          return .init(objcEvent: .sessionStart, description: "session_start")
//        case .appClose:
//          return .init(objcEvent: .appClose, description: "app_close")
//        case .deepLink(let url):
//          return .init(objcEvent: .deepLink, params: <#T##[String : Any]?#>, description: "deepLink_open")
//        case .triggerFire(let eventName, let result):
//          return .init(objcEvent: .triggerFire, params: <#T##[String : Any]?#>, description: "trigger_fire")
//        case .paywallOpen(let paywallInfo):
//          return .init(objcEvent: .paywallOpen, params: <#T##[String : Any]?#>, description: "paywall_open")
//        case .paywallClose(let paywallInfo):
//          return .init(objcEvent: .paywallClose, params: <#T##[String : Any]?#>, description: "paywall_close")
//        case .transactionStart(let product, let paywallInfo):
//          return .init(objcEvent: .transactionStart, params: <#T##[String : Any]?#>, description: "transaction_start")
//        case .transactionFail(let error, let paywallInfo):
//          return .init(objcEvent: .transactionFail, params: <#T##[String : Any]?#>, description: "transaction_fail")
//        case .transactionAbandon(let product, let paywallInfo):
//          return .init(objcEvent: .transactionAbandon, params: <#T##[String : Any]?#>, description: "transaction_abandon")
//        case .transactionComplete(let transaction, let product, let paywallInfo):
//          return .init(objcEvent: .transactionComplete, params: <#T##[String : Any]?#>, description: "transaction_complete")
//        case .subscriptionStart(let product, let paywallInfo):
//          return .init(objcEvent: .subscriptionStart, params: <#T##[String : Any]?#>, description: "subscription_start")
//        case .freeTrialStart(let product, let paywallInfo):
//          return .init(objcEvent: .freeTrialStart, params: <#T##[String : Any]?#>, description: "freeTrial_start")
//        case .transactionRestore(let paywallInfo):
//          return .init(objcEvent: .transactionRestore, params: <#T##[String : Any]?#>, description: "transaction_restore")
//        case .userAttributes(let attributes):
//          return .init(objcEvent: .userAttributes, params: <#T##[String : Any]?#>, description: "user_attributes")
//        case .nonRecurringProductPurchase(let product, let paywallInfo):
//          return .init(objcEvent: .nonRecurringProductPurchase, params: <#T##[String : Any]?#>, description: "nonRecurringProduct_purchase")
//        case .paywallResponseLoadStart(let triggeredEventName):
//          return .init(objcEvent: .paywallResponseLoadStart, params: <#T##[String : Any]?#>, description: "paywallResponseLoad_start")
//        case .paywallResponseLoadNotFound(let triggeredEventName):
//          return .init(objcEvent: .paywallResponseLoadNotFound, params: <#T##[String : Any]?#>, description: "paywallResponseLoad_notFound")
//        case .paywallResponseLoadFail(let triggeredEventName):
//          return .init(objcEvent: .paywallResponseLoadFail, params: <#T##[String : Any]?#>, description: "paywallResponseLoad_fail")
//        case .paywallResponseLoadComplete(let triggeredEventName, let paywallInfo):
//          return .init(objcEvent: .paywallResponseLoadComplete, params: <#T##[String : Any]?#>, description: "paywallResponseLoad_complete")
//        case .paywallWebviewLoadStart(let paywallInfo):
//          return .init(objcEvent: .paywallWebviewLoadStart, params: <#T##[String : Any]?#>, description: "paywallWebviewLoad_start")
//        case .paywallWebviewLoadFail(let paywallInfo):
//          return .init(objcEvent: .paywallWebviewLoadFail, params: <#T##[String : Any]?#>, description: "paywallWebviewLoad_fail")
//        case .paywallWebviewLoadComplete(let paywallInfo):
//          return .init(objcEvent: .paywallWebviewLoadComplete, params: <#T##[String : Any]?#>, description: "paywallWebviewLoad_complete")
//        case .paywallWebviewLoadTimeout(let paywallInfo):
//          return .init(objcEvent: .paywallWebviewLoadTimeout, params: <#T##[String : Any]?#>, description: "paywallWebviewLoad_timeout")
//        case .paywallProductsLoadStart(let triggeredEventName, let paywallInfo):
//          return .init(objcEvent: .paywallProductsLoadStart, params: <#T##[String : Any]?#>, description: "paywallProductsLoad_start")
//        case .paywallProductsLoadFail(let triggeredEventName, let paywallInfo):
//          return .init(objcEvent: .paywallProductsLoadFail, params: <#T##[String : Any]?#>, description: "paywallProductsLoad_fail")
//        case .paywallProductsLoadComplete(let triggeredEventName):
//          return .init(objcEvent: .paywallProductsLoadComplete, params: <#T##[String : Any]?#>, description: "paywallProductsLoad_complete")
//        }
    }
}
