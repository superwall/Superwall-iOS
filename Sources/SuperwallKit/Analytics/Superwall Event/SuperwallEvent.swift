//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/04/2022.
//

import Foundation

/// Analytical events that are automatically tracked by Superwall.
///
/// These events are tracked internally by the SDK and sent to the delegate method ``SuperwallDelegate/handleSuperwallEvent(withInfo:)-pm3v``.
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

  /// When the app is opened at least an hour since last  ``appClose``.
  ///
  /// The raw value of this event can be added to a campaign to trigger a paywall.
  case sessionStart

  /// When the user's subscription status changes.
  case subscriptionStatusDidChange

  /// Anytime the app leaves the foreground.
  case appClose

  /// When a user opens the app via a deep link.
  ///
  /// The raw value of this event can be added to a campaign to trigger a paywall.
  case deepLink(url: URL)

  /// When the tracked event matches an event added as a paywall trigger in a campaign.
  ///
  /// The result of firing the trigger is accessible in the `result` associated value.
  case triggerFire(eventName: String, result: TriggerResult)

  /// When a paywall is opened.
  case paywallOpen(paywallInfo: PaywallInfo)

  /// When a paywall is closed.
  case paywallClose(paywallInfo: PaywallInfo)

  /// When the payment sheet is displayed to the user.
  case transactionStart(product: StoreProduct, paywallInfo: PaywallInfo)

  /// When the payment sheet fails to complete a transaction (ignores user canceling the transaction).
  case transactionFail(error: TransactionError, paywallInfo: PaywallInfo)

  /// When the user cancels a transaction.
  case transactionAbandon(product: StoreProduct, paywallInfo: PaywallInfo)

  /// When the user completes checkout in the payment sheet and any product was purchased.
  case transactionComplete(transaction: StoreTransaction, product: StoreProduct, paywallInfo: PaywallInfo)

  /// When the user successfully completes a transaction for a subscription product with no introductory offers.
  case subscriptionStart(product: StoreProduct, paywallInfo: PaywallInfo)

  /// When the user successfully completes a transaction for a subscription product with an introductory offer.
  case freeTrialStart(product: StoreProduct, paywallInfo: PaywallInfo)

  /// When the user successfully restores their purchases.
  case transactionRestore(paywallInfo: PaywallInfo)

  /// When the transaction took > 5 seconds to show the payment sheet.
  case transactionTimeout(paywallInfo: PaywallInfo)

  /// When the user attributes are set.
  case userAttributes(_ attributes: [String: Any])

  /// When the user purchased a non recurring product.
  case nonRecurringProductPurchase(product: TransactionProduct, paywallInfo: PaywallInfo)

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

  /// When the paywall fails to present.
  case paywallPresentationFail(reason: PaywallPresentationFailureReason)

  var canImplicitlyTriggerPaywall: Bool {
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

    init(objcEvent: SuperwallEventObjc) {
      self.objcEvent = objcEvent
      self.description = objcEvent.description
    }
  }

  var backingData: BackingData {
    switch self {
    case .firstSeen:
      return .init(objcEvent: .firstSeen)
    case .appOpen:
      return .init(objcEvent: .appOpen)
    case .appLaunch:
      return .init(objcEvent: .appLaunch)
    case .appInstall:
      return .init(objcEvent: .appInstall)
    case .sessionStart:
      return .init(objcEvent: .sessionStart)
    case .subscriptionStatusDidChange:
      return .init(objcEvent: .subscriptionStatusDidChange)
    case .appClose:
      return .init(objcEvent: .appClose)
    case .deepLink:
      return .init(objcEvent: .deepLink)
    case .triggerFire:
      return .init(objcEvent: .triggerFire)
    case .paywallOpen:
      return .init(objcEvent: .paywallOpen)
    case .paywallClose:
      return .init(objcEvent: .paywallClose)
    case .transactionStart:
      return .init(objcEvent: .transactionStart)
    case .transactionFail:
      return .init(objcEvent: .transactionFail)
    case .transactionAbandon:
      return .init(objcEvent: .transactionAbandon)
    case .transactionTimeout:
      return .init(objcEvent: .transactionTimeout)
    case .transactionComplete:
      return .init(objcEvent: .transactionComplete)
    case .subscriptionStart:
      return .init(objcEvent: .subscriptionStart)
    case .freeTrialStart:
      return .init(objcEvent: .freeTrialStart)
    case .transactionRestore:
      return .init(objcEvent: .transactionRestore)
    case .userAttributes:
      return .init(objcEvent: .userAttributes)
    case .nonRecurringProductPurchase:
      return .init(objcEvent: .nonRecurringProductPurchase)
    case .paywallResponseLoadStart:
      return .init(objcEvent: .paywallResponseLoadStart)
    case .paywallResponseLoadNotFound:
      return .init(objcEvent: .paywallResponseLoadNotFound)
    case .paywallResponseLoadFail:
      return .init(objcEvent: .paywallResponseLoadFail)
    case .paywallResponseLoadComplete:
      return .init(objcEvent: .paywallResponseLoadComplete)
    case .paywallWebviewLoadStart:
      return .init(objcEvent: .paywallWebviewLoadStart)
    case .paywallWebviewLoadFail:
      return .init(objcEvent: .paywallWebviewLoadFail)
    case .paywallWebviewLoadComplete:
      return .init(objcEvent: .paywallWebviewLoadComplete)
    case .paywallWebviewLoadTimeout:
      return .init(objcEvent: .paywallWebviewLoadTimeout)
    case .paywallProductsLoadStart:
      return .init(objcEvent: .paywallProductsLoadStart)
    case .paywallProductsLoadFail:
      return .init(objcEvent: .paywallProductsLoadFail)
    case .paywallProductsLoadComplete:
      return .init(objcEvent: .paywallProductsLoadComplete)
    case .paywallPresentationFail(reason: let reason):
      switch reason {
      case .userIsSubscribed:
        return .init(objcEvent: .paywallPresentationFailUserIsSubscribed)
      case .holdout:
        return .init(objcEvent: .paywallPresentationFailInHoldout)
      case .noRuleMatch:
        return .init(objcEvent: .paywallPresentationFailNoRuleMatch)
      case .eventNotFound:
        return .init(objcEvent: .paywallPresentationFailEventNotFound)
      case .debuggerLaunched:
        return .init(objcEvent: .paywallPresentationFailDebuggerLaunched)
      case .alreadyPresented:
        return .init(objcEvent: .paywallPresentationFailAlreadyPresented)
      case .noPresenter:
        return .init(objcEvent: .paywallPresentationFailNoPresenter)
      case .noPaywallViewController:
        return .init(objcEvent: .paywallPresentationFailNoPaywallViewController)
      }
    }
  }
}

// This is unchecked because of the use of `Any` in `[String: Any]` user attributes.
// Everything else is Sendable except that.
extension SuperwallEvent: @unchecked Sendable {}
