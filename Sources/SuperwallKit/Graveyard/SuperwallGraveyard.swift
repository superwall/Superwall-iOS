//
//  File.swift
//  
//
//  Created by Yusuf Tör on 04/10/2022.
//

import UIKit

extension Superwall {
  // MARK: - Unavailable methods
  @available(*, unavailable, renamed: "preloadPaywalls(forEvents:)")
  @objc public func preloadPaywalls(forTriggers triggers: Set<String>) {}

  @available(*, unavailable, renamed: "register(placement:params:handler:feature:)")
  @objc public func trigger(
    event: String? = nil,
    params: [String: Any]? = nil,
    on viewController: UIViewController? = nil,
    ignoreSubscriptionStatus: Bool = false,
    presentationStyleOverride: PaywallPresentationStyle = .none,
    onSkip: ((NSError?) -> Void)? = nil,
    onPresent: ((PaywallInfo) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo) -> Void)? = nil
  ) {}

  @available(*, unavailable, renamed: "register(placement:params:)")
  @objc public func track(
    _ name: String,
    _ params: [String: Any] = [:]
  ) {}

  @available(*, unavailable, message: "Set the SuperwallOption \"localeIdentifier\" instead.")
  @objc public func localizationOverride(localeIdentifier: String? = nil) {}

  @available(*, unavailable, renamed: "SuperwallEvent")
  public enum EventName: String {
    case fakeCase = "fake"
  }

  /// Registers an event to access a feature. When the event is added to a campaign on the Superwall dashboard, it can show a paywall.
  ///
  /// This shows a paywall to the user when: An event you provide is added to a campaign on the [Superwall Dashboard](https://superwall.com/dashboard); the user matches a rule in the campaign; and the user doesn't have an active subscription.
  ///
  /// Before using this method, you'll first need to create a campaign and add the event to the campaign on the [Superwall Dashboard](https://superwall.com/dashboard).
  ///
  /// The paywall shown to the user is determined by the rules defined in the campaign. When a user is assigned a paywall within a rule, they will continue to see that paywall unless you remove the paywall from the rule or reset assignments to the paywall.
  ///
  /// - Parameters:
  ///   -  event: The name of the event you wish to register.
  ///   - params: Optional parameters you'd like to pass with your event. These can be referenced within the rules of your campaign. Keys beginning with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped. Defaults to `nil`.
  ///   - handler: An optional handler whose functions provide status updates for a paywall. Defaults to `nil`.
  ///   - feature: A completion block containing a feature that you wish to paywall. Access to this block is remotely configurable via the [Superwall Dashboard](https://superwall.com/dashboard). If the paywall is set to _Non Gated_, this will be called when the paywall is dismissed or if the user is already paying. If the paywall is _Gated_, this will be called only if the user is already paying or if they begin paying. If no paywall is configured, this gets called immediately. This will not be called in the event of an error, which you can detect via the `handler`.
  @available(*, deprecated, renamed: "register(placement:params:handler:feature:)")
  public func register(
    event: String,
    params: [String: Any]? = nil,
    handler: PaywallPresentationHandler? = nil,
    feature: @escaping () -> Void
  ) {
    register(
      placement: event,
      params: params,
      handler: handler,
      feature: feature
    )
  }

  /// Registers an event which, when added to a campaign on the Superwall dashboard, can show a paywall.
  ///
  /// This shows a paywall to the user when: An event you provide is added to a campaign on the [Superwall Dashboard](https://superwall.com/dashboard); the user matches a rule in the campaign; and the user doesn't have an active subscription.
  ///
  /// Before using this method, you'll first need to create a campaign and add the event to the campaign on the [Superwall Dashboard](https://superwall.com/dashboard).
  ///
  /// The paywall shown to the user is determined by the rules defined in the campaign. When a user is assigned a paywall within a rule, they will continue to see that paywall unless you remove the paywall from the rule or reset assignments to the paywall.
  ///
  /// - Parameters:
  ///   -  event: The name of the event you wish to register.
  ///   - params: Optional parameters you'd like to pass with your event. These can be referenced within the rules of your campaign. Keys beginning with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped. Defaults to `nil`.
  ///   - handler: An optional handler whose functions provide status updates for a paywall. Defaults to `nil`.
  @available(*, deprecated, renamed: "register(placement:params:handler:)")
  public func register(
    event: String,
    params: [String: Any]? = nil,
    handler: PaywallPresentationHandler? = nil
  ) {
    register(
      placement: event,
      params: params,
      handler: handler
    )
  }

  /// Objective-C-only convenience method. Registers an event which, when added to a campaign on the Superwall dashboard, can show a paywall.
  ///
  /// This shows a paywall to the user when: An event you provide is added to a campaign on the [Superwall Dashboard](https://superwall.com/dashboard); the user matches a rule in the campaign; and the user doesn't have an active subscription.
  ///
  /// Before using this method, you'll first need to create a campaign and add the event to the campaign on the [Superwall Dashboard](https://superwall.com/dashboard).
  ///
  /// The paywall shown to the user is determined by the rules defined in the campaign. When a user is assigned a paywall within a rule, they will continue to see that paywall unless you remove the paywall from the rule or reset assignments to the paywall.
  ///
  /// - Parameters:
  ///   -  event: The name of the event you wish to register.
  @available(swift, obsoleted: 1.0)
  @available(*, deprecated, renamed: "register(placement:)")
  @objc public func register(event: String) {
    register(placement: event)
  }

  /// Objective-C-only convenience method. Registers an event which, when added to a campaign on the Superwall dashboard, can show a paywall.
  ///
  /// This shows a paywall to the user when: An event you provide is added to a campaign on the [Superwall Dashboard](https://superwall.com/dashboard); the user matches a rule in the campaign; and the user doesn't have an active subscription.
  ///
  /// Before using this method, you'll first need to create a campaign and add the event to the campaign on the [Superwall Dashboard](https://superwall.com/dashboard).
  ///
  /// The paywall shown to the user is determined by the rules defined in the campaign. When a user is assigned a paywall within a rule, they will continue to see that paywall unless you remove the paywall from the rule or reset assignments to the paywall.
  ///
  /// - Parameters:
  ///   -  event: The name of the event you wish to register.
  ///   - params: Optional parameters you'd like to pass with your event. These can be referenced within the rules of your campaign. Keys beginning with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped. Defaults to `nil`.
  @available(swift, obsoleted: 1.0)
  @available(*, deprecated, renamed: "register(placement:params:)")
  @objc public func register(
    event: String,
    params: [String: Any]?
  ) {
    register(placement: event, params: params)
  }

  /// Returns a publisher that registers an event which, when added to a campaign on the Superwall dashboard, can show a paywall.
  ///
  /// This shows a paywall to the user when: An event you provide is added to a campaign on the [Superwall Dashboard](https://superwall.com/dashboard); the user matches a rule in the campaign; and the user doesn't have an active subscription.
  ///
  /// Before using this method, you'll first need to create a campaign and add the event to the campaign on the [Superwall Dashboard](https://superwall.com/dashboard).
  ///
  /// The paywall shown to the user is determined by the rules defined in the campaign. When a user is assigned a paywall within a rule, they will continue to see that paywall unless you remove the paywall from the rule or reset assignments to the paywall.
  ///
  /// - Parameters:
  ///   -  event: The name of the event you wish to register.
  ///   - params: Optional parameters you'd like to pass with your event. These can be referenced within the rules of your campaign. Keys beginning with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///   - paywallOverrides: An optional ``PaywallOverrides`` object whose parameters override the paywall defaults. Use this to override products, presentation style, and whether it ignores the subscription status. Defaults to `nil`.
  ///
  /// - Returns: A publisher that provides updates on the state of the paywall via a ``PaywallState`` object.
  @available(*, deprecated, renamed: "publisher(forPlacement:params:paywallOverrides:isFeatureGatable:)")
  public func publisher(
    forEvent event: String,
    params: [String: Any]? = nil,
    paywallOverrides: PaywallOverrides? = nil,
    isFeatureGatable: Bool
  ) -> PaywallStatePublisher {
    return publisher(
      forPlacement: event,
      params: params,
      paywallOverrides: paywallOverrides,
      isFeatureGatable: isFeatureGatable
    )
  }
}
