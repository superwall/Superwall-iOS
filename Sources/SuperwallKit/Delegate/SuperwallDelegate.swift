//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/01/2023.
//

import Foundation

/// The delegate protocol that handles Superwall lifecycle events.
///
/// The delegate methods receive callbacks from the SDK in response to certain events that happen on the paywall.
///
/// You set this directly using ``Superwall/delegate``.
///
/// To learn how to conform to the delegate in your app and best practices, see
/// [our docs](https://docs.superwall.com/docs/3rd-party-analytics).
public protocol SuperwallDelegate: AnyObject {
  /// Called when the ``Superwall/subscriptionStatus`` changes.
  ///
  /// You can use this function to update the state of your application. Alternatively, you can
  /// use the published property ``Superwall/subscriptionStatus`` to react to
  /// changes as they happen.
  ///
  /// - Parameters:
  ///   - oldValue: The old value of the ``Superwall/subscriptionStatus``.
  ///   - newValue: The new value of the ``Superwall/subscriptionStatus``.
  @MainActor
  func subscriptionStatusDidChange(
    from oldValue: SubscriptionStatus,
    to newValue: SubscriptionStatus
  )

  /// Called whenever an internal analytics event is tracked.
  ///
  /// Use this method when you want to track internal analytics events in your own analytics.
  ///
  /// You can switch over `eventInfo.event` for a list of possible cases. See [Superwall Placements](https://docs.superwall.com/docs/tracking-analytics) for more info.
  ///
  /// - Parameter eventInfo: A ``SuperwallEventInfo`` object containing a `event` and a `params` parameter.
  @MainActor
  func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo)

  /// Called whenever an internal analytics placement is tracked.
  ///
  /// Use this method when you want to track internal analytics placements in your own analytics.
  ///
  /// You can switch over `placementInfo.placement` for a list of possible cases. See [Superwall Placements](https://docs.superwall.com/docs/tracking-analytics) for more info.
  ///
  /// - Parameter eventInfo: A ``SuperwallPlacementInfo`` object containing a `placement` and a `params` parameter.
  @MainActor
  @available(*, deprecated, renamed: "handleSuperwallEvent(withInfo:)")
  func handleSuperwallPlacement(withInfo placementInfo: SuperwallPlacementInfo)

  /// Called when the user taps an element on your paywall that has the click action `Custom action`,
  /// or a `data-pw-custom` tag attached.
  ///
  /// To learn more about using this function, see [Custom Paywall Actions](https://docs.superwall.com/docs/custom-paywall-events).
  /// To learn about the types of tags that can be attached to elements on your paywall, see [Data Tags](https://docs.superwall.com/docs/data-tags).
  ///
  ///  - Parameter name: The value of the `data-pw-custom` tag in your HTML element that the user selected.
  @MainActor
  func handleCustomPaywallAction(withName name: String)

  /// Called right before the paywall is dismissed.
  @MainActor
  func willDismissPaywall(withInfo paywallInfo: PaywallInfo)

  /// Called right before the paywall is presented.
  @MainActor
  func willPresentPaywall(withInfo paywallInfo: PaywallInfo)

  /// Called right after the paywall is dismissed.
  @MainActor
  func didDismissPaywall(withInfo paywallInfo: PaywallInfo)

  /// Called right after the paywall is presented.
  @MainActor
  func didPresentPaywall(withInfo paywallInfo: PaywallInfo)

  /// Called when the user opens a URL by selecting an element on your paywall that has a `data-pw-open-url` tag.
  ///
  /// - Parameter url: The URL to open
  @MainActor
  func paywallWillOpenURL(url: URL)

  /// Called when the user taps a deep link in your paywall.
  ///
  /// - Parameter url: The deep link URL to open
  @MainActor
  func paywallWillOpenDeepLink(url: URL)

  /// Receive all the log messages generated by the SDK.
  ///
  /// - Parameters:
  ///   - level: Specifies the detail of the logs returned from the SDK to the console.
  ///   Can be either `DEBUG`, `INFO`, `WARN`, or `ERROR`, as defined by ``LogLevel``.
  ///   - scope: The possible scope of logs to print to the console, as defined by ``LogScope``.
  ///   - message: The message associated with the log.
  ///   - info: A dictionary of information associated with the log.
  ///   - error: The error associated with the log.
  @MainActor
  func handleLog(
    level: String,
    scope: String,
    message: String?,
    info: [String: Any]?,
    error: Swift.Error?
  )

//  @MainActor
//  func didRedeemCode(redeemResponse: RedeemResponse)
}

extension SuperwallDelegate {
  public func subscriptionStatusDidChange(
    from oldValue: SubscriptionStatus,
    to newValue: SubscriptionStatus
  ) {}

  public func handleCustomPaywallAction(withName name: String) {}

  public func willDismissPaywall(withInfo paywallInfo: PaywallInfo) {}

  public func willPresentPaywall(withInfo paywallInfo: PaywallInfo) {}

  public func didDismissPaywall(withInfo paywallInfo: PaywallInfo) {}

  public func didPresentPaywall(withInfo paywallInfo: PaywallInfo) {}

  public func paywallWillOpenURL(url: URL) {}

  public func paywallWillOpenDeepLink(url: URL) {}

  public func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {}

  @available(*, deprecated, renamed: "handleSuperwallEvent(withInfo:)")
  public func handleSuperwallPlacement(withInfo placementInfo: SuperwallPlacementInfo) {}

  public func handleLog(
    level: String,
    scope: String,
    message: String?,
    info: [String: Any]?,
    error: Swift.Error?
  ) {}
}
