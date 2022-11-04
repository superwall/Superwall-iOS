//
//  File.swift
//  
//
//  Created by Jake Mor on 10/9/21.
//

import Foundation
import Combine
import UIKit

/// A completion block that contains a ``PaywallDismissedResult`` object. This contains info about why the paywall was dismissed.
public typealias PaywallDismissedCompletionBlock = (PaywallDismissedResult) -> Void

public extension Superwall {
  /// Dismisses the presented paywall.
  /// 
	/// - Parameters:
  ///   - completion: An optional completion block that gets called after the paywall is dismissed. Defaults to nil.
  @MainActor
  static func dismiss(_ completion: (() -> Void)? = nil) {
		guard let paywallViewController = shared.paywallViewController else {
      return
    }
    shared.dismiss(
      paywallViewController,
      state: .closed,
      completion: completion
    )
	}

  /// Dismisses the presented paywall.
  @MainActor
  @objc static func dismiss() async {
    guard let paywallViewController = shared.paywallViewController else {
      return
    }
    return await withCheckedContinuation { continuation in
      shared.dismiss(
        paywallViewController,
        state: .closed
      ) {
        continuation.resume()
      }
    }
  }

  /// An Objective-C-only method that shows a paywall to the user when: An event you provide is tied to an active trigger inside a campaign on the [Superwall Dashboard](https://superwall.com/dashboard); and the user matches a rule in the campaign. **Note**: Please use ``SuperwallKit/Superwall/setUserAttributes(_:)`` if you’re using Swift.
  ///
  /// Triggers enable you to retroactively decide where or when to show a specific paywall in your app. Use this method when you want to remotely control paywall presentation in response to your own analytics event and utilize completion handlers associated with the paywall presentation state.
  ///
  /// Before using this method, you'll first need to create a campaign and add a trigger associated with the event name on the [Superwall Dashboard](https://superwall.com/dashboard).
  ///
  /// The paywall shown to the user is determined by the rules defined in the campaign. Paywalls are sticky, in that when a user is assigned a paywall within a rule, they will continue to see that paywall unless you remove the paywall from the rule.
  ///
  /// For more information, see <doc:TrackingEvents>.
  ///
  /// - Parameters:
  ///   -  event: The name of the event you wish to track.
  ///   - params: Optional parameters you'd like to pass with your event. These can be referenced within the rules of your campaign. Keys beginning with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///   - on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
  ///   - products: An optional ``PaywallProducts`` object whose products replace the remotely defined paywall products. Defauls to `nil`.
  ///   - ignoreSubscriptionStatus: Presents the paywall regardless of subscription status if `true`. Defaults to `false`.
  ///   - presentationStyleOverride: A `PaywallPresentationStyle` object that overrides the presentation style of the paywall set on the dashboard. Defaults to `.none`.
  ///   - onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a ``PaywallInfo`` object containing information about the paywall.
  ///   - onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a ``PaywallInfo`` object containing information about the paywall.
  ///   - onSkip: A completion block that gets called when the paywall's presentation is skipped. Defaults to `nil`.  Accepts an `NSError?` with more details. It is recommended to check the error code to handle the onSkip callback. If the error code is `4000`, it means the user didn't match any rules. If the error code is `4001` it means the user is in a holdout group. Otherwise, a `404` error code means an error occurred.
  @available(swift, obsoleted: 1.0)
  @objc static func track(
    event: String,
    params: [String: Any]? = nil,
    products: PaywallProducts? = nil,
    ignoreSubscriptionStatus: Bool = false,
    presentationStyleOverride: PaywallPresentationStyle = .none,
    onSkip: ((Error?) -> Void)? = nil,
    onPresent: ((PaywallInfo) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo) -> Void)? = nil
  ) {
    let overrides = PaywallOverrides(
      products: products,
      ignoreSubscriptionStatus: ignoreSubscriptionStatus,
      presentationStyleOverride: presentationStyleOverride
    )

    trackCancellable = publisher(
      forEvent: event,
      params: params,
      paywallOverrides: overrides
    )
    .sink { state in
      switch state {
      case .presented(let paywallInfo):
        onPresent?(paywallInfo)
      case .dismissed(let result):
        if let onDismiss = onDismiss {
          onDismissConverter(result, completion: onDismiss)
        }
      case .skipped(let reason):
        onSkipConverter(reason: reason, completion: onSkip)
      }
    }
  }

  /// Tracks an event which, when added to a campaign on the Superwall dashboard, can show a paywall.
  ///
  /// This shows a paywall to the user when: An event you provide is added to a campaign on the [Superwall Dashboard](https://superwall.com/dashboard); the user matches a rule in the campaign; and the user doesn't have an active subscription.
  ///
  /// Before using this method, you'll first need to create a campaign and add the event to the campaign on the [Superwall Dashboard](https://superwall.com/dashboard).
  ///
  /// The paywall shown to the user is determined by the rules defined in the campaign. When a user is assigned a paywall within a rule, they will continue to see that paywall unless you remove the paywall from the rule or reset assignments to the paywall.
  ///
  /// For more information, see <doc:TrackingEvents>.
  ///
  /// - Parameters:
  ///   -  event: The name of the event you wish to track.
  ///   - params: Optional parameters you'd like to pass with your event. These can be referenced within the rules of your campaign. Keys beginning with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///   - paywallOverrides: An optional ``PaywallOverrides`` object whose parameters override the paywall defaults. Use this to override products, presentation style, and whether it ignores the subscription status. Defaults to `nil`.
  ///   - paywallState: An optional callback that provides updates on the state of the paywall via a ``PaywallState`` object.
  static func track(
    event: String,
    params: [String: Any]? = nil,
    paywallOverrides: PaywallOverrides? = nil,
    paywallState: ((PaywallState) -> Void)? = nil
  ) {
    trackCancellable = publisher(
      forEvent: event,
      params: params,
      paywallOverrides: paywallOverrides
    )
    .sink { state in
      paywallState?(state)
    }
  }

  /// Returns a publisher that tracks an event which, when added to a campaign on the Superwall dashboard, can show a paywall.
  ///
  /// This shows a paywall to the user when: An event you provide is added to a campaign on the [Superwall Dashboard](https://superwall.com/dashboard); the user matches a rule in the campaign; and the user doesn't have an active subscription.
  ///
  /// Before using this method, you'll first need to create a campaign and add the event to the campaign on the [Superwall Dashboard](https://superwall.com/dashboard).
  ///
  /// The paywall shown to the user is determined by the rules defined in the campaign. When a user is assigned a paywall within a rule, they will continue to see that paywall unless you remove the paywall from the rule or reset assignments to the paywall.
  ///
  /// For more information, see <doc:TrackingEvents>.
  ///
  /// - Parameters:
  ///   -  event: The name of the event you wish to track.
  ///   - params: Optional parameters you'd like to pass with your event. These can be referenced within the rules of your campaign. Keys beginning with `$` are reserved for Superwall and will be dropped. Values can be any JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will be dropped.
  ///   - paywallOverrides: An optional ``PaywallOverrides`` object whose parameters override the paywall defaults. Use this to override products, presentation style, and whether it ignores the subscription status. Defaults to `nil`.
  ///
  /// - Returns: A publisher that provides updates on the state of the paywall via a ``PaywallState`` object.
  static func publisher(
    forEvent event: String,
    params: [String: Any]? = nil,
    paywallOverrides: PaywallOverrides? = nil
  ) -> PaywallStatePublisher {
    return Future {
      let trackableEvent = UserInitiatedEvent.Track(
        rawName: event,
        canImplicitlyTriggerPaywall: false,
        customParameters: params ?? [:]
      )
      return await track(trackableEvent)
    }
    .flatMap { result in
      let presentationRequest = PresentationRequest(
        presentationInfo: .explicitTrigger(result.data),
        paywallOverrides: paywallOverrides
      )
      return shared.internallyPresent(presentationRequest)
    }
    .eraseToAnyPublisher()
  }

  /// Converts dismissal result from enums with associated values, to old objective-c compatible way
  ///
  /// - Parameters:
  ///   - result: The dismissal result
  ///   - completion: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a ``PaywallInfo`` object containing information about the paywall.
  private static func onDismissConverter(
    _ result: PaywallDismissedResult,
    completion: (Bool, String?, PaywallInfo) -> Void
  ) {
    switch result.state {
    case .closed:
      completion(false, nil, result.paywallInfo)
    case .purchased(productId: let productId):
      completion(true, productId, result.paywallInfo)
    case .restored:
      completion(true, nil, result.paywallInfo)
    }
  }

  private static func onSkipConverter(
    reason: PaywallSkippedReason,
    completion: ((Error?) -> Void)?
  ) {
    switch reason {
    case .holdout(let experiment):
      let userInfo: [String: Any] = [
        "experimentId": experiment.id,
        "variantId": experiment.variant.id,
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Trigger Holdout",
          value: "This user was assigned to a holdout in a trigger experiment",
          comment: "ExperimentId: \(experiment.id), VariantId: \(experiment.variant.id)"
        )
      ]
      let error = NSError(
        domain: "com.superwall",
        code: 4001,
        userInfo: userInfo
      )
      completion?(error)
    case .noRuleMatch:
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "No rule match",
          value: "The user did not match any rules configured for this trigger",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "com.superwall",
        code: 4000,
        userInfo: userInfo
      )
      completion?(error)
    case .eventNotFound:
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Event Not Found",
          value: "The specified event could not be found in a campaign",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "com.superwall",
        code: 404,
        userInfo: userInfo
      )
      completion?(error)
    case .error(let error):
      completion?(error)
    }
  }
}
