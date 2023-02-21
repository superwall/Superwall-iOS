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
/// To learn how to conform to the delegate in your app and best practices, see <doc:AdvancedConfiguration>.
public protocol SuperwallDelegate: AnyObject {
  /// Called when the user taps an element on your paywall that has the click action `Custom action`,
  /// or a `data-pw-custom` tag attached.
  ///
  /// To learn more about using this function, see <doc:CustomPaywallButtons>. To learn about the types of tags that can
  /// be attached to elements on your paywall, see [Data Tags](https://docs.superwall.com/docs/data-tags).
  ///
  ///  - Parameter name: The value of the `data-pw-custom` tag in your HTML element that the user selected.
  @MainActor
  func handleCustomPaywallAction(withName name: String)

  /// Called right before the paywall is dismissed.
  @MainActor
  func willDismissPaywall()

  /// Called right before the paywall is presented.
  @MainActor
  func willPresentPaywall()

  /// Called right after the paywall is dismissed.
  @MainActor
  func didDismissPaywall()

  /// Called right after the paywall is presented.
  @MainActor
  func didPresentPaywall()

  /// Called when the user opens a URL by selecting an element on your paywall that has a `data-pw-open-url` tag.
  ///
  /// - Parameter url: The URL to open
  @MainActor
  func willOpenURL(url: URL)

  /// Called when the user taps a deep link in your paywall.
  ///
  /// - Parameter url: The deep link URL to open
  @MainActor
  func willOpenDeepLink(url: URL)

  /// Called whenever an internal analytics event is tracked.
  ///
  /// Use this method when you want to track internal analytics events in your own analytics.
  ///
  /// You can switch over `info.event` for a list of possible cases. See <doc:SuperwallEvents> for more info.
  ///
  /// - Parameter info: A `SuperwallEventInfo` object containing an `event` and a `params` parameter.
  @MainActor
  func didTrackSuperwallEventInfo(_ info: SuperwallEventInfo)

  /// Called when the property ``Superwall/subscriptionStatus`` changes.
  ///
  /// If you're letting Superwall handle subscription-related logic, then this is based on
  /// the device receipt. Otherwise, this will reflect the value that you set.
  ///
  /// You can use this function to update the state of your application. Alternatively, you can
  /// use the published properties of ``Superwall/subscriptionStatus`` to react to
  /// changes as they happen.
  ///
  /// - Parameters:
  ///   - newValue: The new value of ``Superwall/subscriptionStatus``.
  func subscriptionStatusDidChange(to newValue: SubscriptionStatus)

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
}

extension SuperwallDelegate {
  public func handleCustomPaywallAction(withName name: String) {}

  public func willDismissPaywall() {}

  public func willPresentPaywall() {}

  public func didDismissPaywall() {}

  public func didPresentPaywall() {}

  public func willOpenURL(url: URL) {}

  public func willOpenDeepLink(url: URL) {}

  public func didTrackSuperwallEventInfo(_ info: SuperwallEventInfo) {}

  public func subscriptionStatusDidChange(to newValue: SubscriptionStatus) {}

  public func handleLog(
    level: String,
    scope: String,
    message: String?,
    info: [String: Any]?,
    error: Swift.Error?
  ) {}
}