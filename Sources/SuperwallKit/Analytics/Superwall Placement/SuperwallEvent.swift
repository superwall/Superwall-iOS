//
//  File.swift
//
//
//  Created by Yusuf Tör on 21/04/2022.
//
// swiftlint:disable file_length

import Foundation

/// Analytical placements that are automatically tracked by Superwall.
///
/// These placement are tracked internally by the SDK and sent to the delegate method ``SuperwallDelegate/handleSuperwallEvent(withInfo:)-50exd``.
public typealias SuperwallPlacement = SuperwallEvent

/// Analytical events that are automatically tracked by Superwall.
///
/// These events are tracked internally by the SDK and sent to the delegate method ``SuperwallDelegate/handleSuperwallEvent(withInfo:)-50exd``.
public enum SuperwallEvent {
  /// When the user is first seen in the app, regardless of whether the user is logged in or not.
  case firstSeen

  /// Anytime the app enters the foreground
  case appOpen

  /// When the app is launched from a cold start
  ///
  /// The raw value of this placement can be added to a campaign to trigger a paywall.
  case appLaunch

  /// When the user's identity aliases after calling identify
  case identityAlias

  /// When the SDK is configured for the first time.
  ///
  /// The raw value of this placement can be added to a campaign to trigger a paywall.
  case appInstall

  /// When the app is opened at least an hour since last  ``appClose``.
  ///
  /// The raw value of this placement can be added to a campaign to trigger a paywall.
  case sessionStart

  /// When device attributes are sent to the backend.
  case deviceAttributes(attributes: [String: Any])

  /// When the entitlement status did change.
  case subscriptionStatusDidChange

  /// Anytime the app leaves the foreground.
  case appClose

  /// When a user opens the app via a deep link.
  ///
  /// The raw value of this placement can be added to a campaign to trigger a paywall.
  case deepLink(url: URL)

  /// When the registered placement triggers a paywall or holdout.
  ///
  /// The result of firing the trigger is accessible in the `result` associated value.
  case triggerFire(placementName: String, result: TriggerResult)

  /// When a paywall is opened.
  case paywallOpen(paywallInfo: PaywallInfo)

  /// When a paywall is closed.
  case paywallClose(paywallInfo: PaywallInfo)

  /// When a user manually dismisses a paywall.
  case paywallDecline(paywallInfo: PaywallInfo)

  /// When the payment sheet is displayed to the user.
  case transactionStart(product: StoreProduct, paywallInfo: PaywallInfo)

  /// When the payment sheet fails to complete a transaction (ignores user canceling the transaction).
  case transactionFail(error: TransactionError, paywallInfo: PaywallInfo)

  /// When the user cancels a transaction.
  case transactionAbandon(product: StoreProduct, paywallInfo: PaywallInfo)

  /// When the user completes checkout in the payment sheet and any product was purchased.
  ///
  /// - Note: The `transaction` is an optional ``StoreTransaction`` object. Most of the time
  /// this won't be `nil`. However, it could be `nil` if you are using a ``PurchaseController``
  /// and the transaction object couldn't be detected after you return `.purchased` in ``PurchaseController/purchase(product:)``.
  case transactionComplete(
    transaction: StoreTransaction?, product: StoreProduct, type: TransactionType, paywallInfo: PaywallInfo)

  /// When the user successfully completes a transaction for a subscription product with no introductory offers.
  case subscriptionStart(product: StoreProduct, paywallInfo: PaywallInfo)

  /// When the user successfully completes a transaction for a subscription product with an introductory offer.
  case freeTrialStart(product: StoreProduct, paywallInfo: PaywallInfo)

  /// When the user successfully restores purchases..
  case transactionRestore(restoreType: RestoreType, paywallInfo: PaywallInfo)

  /// When the transaction took > 5 seconds to show the payment sheet.
  case transactionTimeout(paywallInfo: PaywallInfo)

  /// When the user attributes are set.
  case userAttributes(_ attributes: [String: Any])

  /// When the user purchased a non recurring product.
  case nonRecurringProductPurchase(product: TransactionProduct, paywallInfo: PaywallInfo)

  /// When a paywall's request to Superwall's servers has started.
  case paywallResponseLoadStart(triggeredPlacementName: String?)

  /// When a paywall's request to Superwall's servers returned a 404 error.
  case paywallResponseLoadNotFound(triggeredPlacementName: String?)

  /// When a paywall's request to Superwall's servers produced an error.
  case paywallResponseLoadFail(triggeredPlacementName: String?)

  /// When a paywall's request to Superwall's servers is complete.
  case paywallResponseLoadComplete(triggeredPlacementName: String?, paywallInfo: PaywallInfo)

  /// When a paywall's website begins to load.
  case paywallWebviewLoadStart(paywallInfo: PaywallInfo)

  /// When a paywall's website fails to load.
  case paywallWebviewLoadFail(paywallInfo: PaywallInfo)

  /// When a paywall's website completes loading.
  case paywallWebviewLoadComplete(paywallInfo: PaywallInfo)

  /// When the loading of a paywall's website times out.
  case paywallWebviewLoadTimeout(paywallInfo: PaywallInfo)

  /// When a paywall's website completes loading.
  case paywallWebviewLoadFallback(paywallInfo: PaywallInfo)

  /// When the request to load the paywall's products started.
  case paywallProductsLoadStart(triggeredPlacementName: String?, paywallInfo: PaywallInfo)

  /// When the request to load the paywall's products failed.
  case paywallProductsLoadFail(triggeredPlacementName: String?, paywallInfo: PaywallInfo)

  /// When the request to load the paywall's products completed.
  case paywallProductsLoadComplete(triggeredPlacementName: String?)

  /// When the request to load the paywall's products has failed and is being retried.
  case paywallProductsLoadRetry(
    triggeredPlacementName: String?, paywallInfo: PaywallInfo, attempt: Int)

  /// When the response to a paywall survey is recorded.
  case surveyResponse(
    survey: Survey,
    selectedOption: SurveyOption,
    customResponse: String?,
    paywallInfo: PaywallInfo
  )

  /// Information about the paywall presentation request
  case paywallPresentationRequest(
    status: PaywallPresentationRequestStatus,
    reason: PaywallPresentationRequestStatusReason?
  )

  /// When the first touch was detected on the UIWindow of the app.
  ///
  /// This is only registered if there's an active `touches_began` trigger on your dashboard.
  case touchesBegan

  /// When the user chose the close button on a survey instead of responding.
  case surveyClose

  /// When ``Superwall/reset()`` is called.
  case reset

  /// When a restore is initiated
  case restoreStart

  /// When a restore fails.
  case restoreFail(message: String)

  /// When a restore completes.
  case restoreComplete

  /// When the Superwall configuration is refreshed.
  case configRefresh

  /// When the user taps on an element in the paywall that has a `custom_placement` action attached to it.
  case customPlacement(name: String, params: [String: Any], paywallInfo: PaywallInfo)

  /// When the attributes that affect the configuration of Superwall are set or change.
  case configAttributes

  /// When all the experiment assignments are confirmed by calling ``Superwall/confirmAllAssignments()``.
  case confirmAllAssignments

  /// When the Superwall configuration fails to be retrieved.
  case configFail

  /// When the AdServices token request starts.
  case adServicesTokenRequestStart

  /// When the AdServices token request fails.
  case adServicesTokenRequestFail(error: Error)

  /// When the AdServices token request finishes.
  case adServicesTokenRequestComplete(token: String)

  /// When the shimmer view starts to show.
  case shimmerViewStart

  /// When the shimmer view stops showing.
  case shimmerViewComplete

  /// When the redemption of a code is initiated.
  case redemptionStart

  /// When the redemption of a code completes.
  case redemptionComplete

  /// When the redemption of a code fails.
  case redemptionFail

  /// When the enrichment request starts.
  case enrichmentStart

  /// When the enrichment request completes.
  case enrichmentComplete(userEnrichment: [String: Any]?, deviceEnrichment: [String: Any]?)

  /// When the enrichment request fails.
  case enrichmentFail

  /// When a response from the network fails to decode.
  case networkDecodingFail

  /// When the customer info did change.
  case customerInfoDidChange

  var canImplicitlyTriggerPaywall: Bool {
    switch self {
    case .appInstall,
      .sessionStart,
      .appLaunch,
      .deepLink,
      .transactionFail,
      .paywallDecline,
      .transactionAbandon,
      .surveyResponse,
      .touchesBegan,
      .customPlacement:
      return true
    default:
      return false
    }
  }
}

// MARK: - CustomStringConvertible
extension SuperwallEvent: CustomStringConvertible {
  /// The string value of the placement name.
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
    case .identityAlias:
      return .init(objcEvent: .identityAlias)
    case .appLaunch:
      return .init(objcEvent: .appLaunch)
    case .appInstall:
      return .init(objcEvent: .appInstall)
    case .sessionStart:
      return .init(objcEvent: .sessionStart)
    case .deviceAttributes:
      return .init(objcEvent: .deviceAttributes)
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
    case .paywallDecline:
      return .init(objcEvent: .paywallDecline)
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
    case .paywallWebviewLoadFallback:
      return .init(objcEvent: .paywallWebviewLoadFallback)
    case .paywallProductsLoadStart:
      return .init(objcEvent: .paywallProductsLoadStart)
    case .paywallProductsLoadFail:
      return .init(objcEvent: .paywallProductsLoadFail)
    case .paywallProductsLoadRetry:
      return .init(objcEvent: .paywallProductsLoadRetry)
    case .paywallProductsLoadComplete:
      return .init(objcEvent: .paywallProductsLoadComplete)
    case .paywallPresentationRequest:
      return .init(objcEvent: .paywallPresentationRequest)
    case .surveyResponse:
      return .init(objcEvent: .surveyResponse)
    case .touchesBegan:
      return .init(objcEvent: .touchesBegan)
    case .surveyClose:
      return .init(objcEvent: .surveyClose)
    case .reset:
      return .init(objcEvent: .reset)
    case .restoreStart:
      return .init(objcEvent: .restoreStart)
    case .restoreFail:
      return .init(objcEvent: .restoreFail)
    case .restoreComplete:
      return .init(objcEvent: .restoreComplete)
    case .configRefresh:
      return .init(objcEvent: .configRefresh)
    case .customPlacement:
      return .init(objcEvent: .customPlacement)
    case .configAttributes:
      return .init(objcEvent: .configAttributes)
    case .confirmAllAssignments:
      return .init(objcEvent: .confirmAllAssignments)
    case .configFail:
      return .init(objcEvent: .configFail)
    case .adServicesTokenRequestStart:
      return .init(objcEvent: .adServicesTokenRequestStart)
    case .adServicesTokenRequestFail:
      return .init(objcEvent: .adServicesTokenRequestFail)
    case .adServicesTokenRequestComplete:
      return .init(objcEvent: .adServicesTokenRequestComplete)
    case .shimmerViewStart:
      return .init(objcEvent: .shimmerViewStart)
    case .shimmerViewComplete:
      return .init(objcEvent: .shimmerViewComplete)
    case .redemptionStart:
      return .init(objcEvent: .redemptionStart)
    case .redemptionComplete:
      return .init(objcEvent: .redemptionComplete)
    case .redemptionFail:
      return .init(objcEvent: .redemptionFail)
    case .enrichmentFail:
      return .init(objcEvent: .enrichmentFail)
    case .enrichmentStart:
      return .init(objcEvent: .enrichmentStart)
    case .enrichmentComplete:
      return .init(objcEvent: .enrichmentComplete)
    case .networkDecodingFail:
      return .init(objcEvent: .networkDecodingFail)
    case .customerInfoDidChange:
      return .init(objcEvent: .customerInfoDidChange)
    }
  }
}

// Using this to silence warnings.
// This is unchecked because of the use of `Any` in `[String: Any]` user attributes.
// Also, PaywallInfo is not Sendable.
extension SuperwallEvent: @unchecked Sendable {}
