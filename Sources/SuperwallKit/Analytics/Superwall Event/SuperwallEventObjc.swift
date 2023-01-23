//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/11/2022.
//

import Foundation

/// Objective-C-only analytical events that are automatically tracked by Superwall.
///
/// These events are tracked internally by the SDK and sent to the delegate method ``SuperwallKit/SuperwallDelegateObjc/didTrackSuperwallEventInfo(_:)``.
@objc(SWKSuperwallEvent)
public enum SuperwallEventObjc: Int {
  /// When the user is first seen in the app, regardless of whether the user is logged in or not.
  case firstSeen

  /// Anytime the app enters the foreground
  case appOpen

  /// When the app is launched from a cold start
  ///
  /// This event can be used to trigger a paywall. Just add the `app_launch` event to a campaign.
  case appLaunch

  /// When the SDK is configured for the first time, or directly after calling ``Superwall/reset()``.
  ///
  /// This event can be used to trigger a paywall. Just add the `app_install` event to a campaign.
  case appInstall

  /// When the app is opened at least an hour since last  ``SuperwallEvent/appClose``.
  ///
  /// This event can be used to trigger a paywall. Just add the `session_start` event to a campaign.
  case sessionStart

  /// Anytime the app leaves the foreground.
  case appClose

  /// When a user opens the app via a deep link.
  ///
  /// This event can be used to trigger a paywall. Just add the `deepLink_open` event to a campaign.
  case deepLink

  /// When the tracked event matches an event added as a paywall trigger in a campaign.
  case triggerFire

  /// When a paywall is opened.
  case paywallOpen

  /// When a paywall is closed.
  case paywallClose

  /// When the payment sheet is displayed to the user.
  case transactionStart

  /// When the payment sheet fails to complete a transaction (ignores user canceling the transaction).
  case transactionFail

  /// When the user cancels a transaction.
  case transactionAbandon

  /// When the user completes checkout in the payment sheet and any product was purchased.
  case transactionComplete

  /// When the user successfully restores their purchases.
  case transactionRestore

  /// When a transaction takes > 5 seconds to show the payment sheet.
  case transactionTimeout

  /// When the user successfully completes a transaction for a subscription product with no introductory offers.
  case subscriptionStart

  /// When the user successfully completes a transaction for a subscription product with an introductory offer.
  case freeTrialStart

  /// When the user attributes are set.
  case userAttributes

  /// When the user purchased a non recurring product.
  case nonRecurringProductPurchase

  /// When a paywall's request to Superwall's servers has started.
  case paywallResponseLoadStart

  /// When a paywall's request to Superwall's servers returned a 404 error.
  case paywallResponseLoadNotFound

  /// When a paywall's request to Superwall's servers produced an error.
  case paywallResponseLoadFail

  /// When a paywall's request to Superwall's servers is complete.
  case paywallResponseLoadComplete

  /// When a paywall's website begins to load.
  case paywallWebviewLoadStart

  /// When a paywall's website fails to load.
  case paywallWebviewLoadFail

  /// When a paywall's website completes loading.
  case paywallWebviewLoadComplete

  /// When the loading of a paywall's website times out.
  case paywallWebviewLoadTimeout

  /// When the request to load the paywall's products started.
  case paywallProductsLoadStart

  /// When the request to load the paywall's products failed.
  case paywallProductsLoadFail

  /// When the request to load the paywall's products completed.
  case paywallProductsLoadComplete

  /// Trying to present paywall when debugger is launched.
  case paywallPresentationFailDebuggerLaunched

  /// Trying to present paywall when debugger is launched.
  case paywallPresentationFailUserIsSubscribed

  /// The user is in a holdout group.
  case paywallPresentationFailInHoldout

  /// No rules defined in the campaign for the event matched.
  case paywallPresentationFailNoRuleMatch

  /// The event provided was not found in any campaign on the dashboard.
  case paywallPresentationFailEventNotFound

  /// There was an error getting the paywall view controller.
  case paywallPresentationFailNoPaywallViewController

  /// There isn't a view to present the paywall on.
  case paywallPresentationFailNoPresenter

  /// There's already a paywall presented.
  case paywallPresentationFailAlreadyPresented

  public init(event: SuperwallEvent) {
    self = event.backingData.objcEvent
  }
}
