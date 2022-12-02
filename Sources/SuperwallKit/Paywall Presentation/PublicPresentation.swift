//
//  File.swift
//  
//
//  Created by Jake Mor on 10/9/21.
//
// swiftlint:disable line_length

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
  ///   - products: An optional ``PaywallProducts`` object whose products replace the remotely defined paywall products. Defauls to `nil`.
  ///   - ignoreSubscriptionStatus: Presents the paywall regardless of subscription status if `true`. Defaults to `false`.
  ///   - presentationStyleOverride: A `PaywallPresentationStyle` object that overrides the presentation style of the paywall set on the dashboard. Defaults to `.none`.
  ///   - onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a ``PaywallInfo`` object containing information about the paywall.
  ///   - onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a ``PaywallInfo`` object containing information about the paywall.
  ///   - onSkip: A completion block that gets called when the paywall's presentation is skipped. Defaults to `nil`.  Accepts a ``PaywallSkippedReasonObjc`` object and an `NSError` with more details.
  @available(swift, obsoleted: 1.0)
  @objc static func track(
    event: String,
    params: [String: Any]? = nil,
    products: PaywallProducts? = nil,
    ignoreSubscriptionStatus: Bool = false,
    presentationStyleOverride: PaywallPresentationStyle = .none,
    onSkip: ((PaywallSkippedReasonObjc, NSError) -> Void)? = nil,
    onPresent: ((PaywallInfo) -> Void)? = nil,
    onDismiss: ((PaywallDismissedResultStateObjc, String?, PaywallInfo) -> Void)? = nil
  ) {
    let overrides = PaywallOverrides(
      products: products,
      ignoreSubscriptionStatus: ignoreSubscriptionStatus,
      presentationStyleOverride: presentationStyleOverride
    )

    track(
      event: event,
      params: params,
      paywallOverrides: overrides
    ) { state in
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
  ///   - paywallHandler: An optional callback that provides updates on the state of the paywall via a ``PaywallState`` object.
  static func track(
    event: String,
    params: [String: Any]? = nil,
    paywallOverrides: PaywallOverrides? = nil,
    paywallHandler: ((PaywallState) -> Void)? = nil
  ) {
    // swiftlint:disable implicitly_unwrapped_optional
    var cancellable: AnyCancellable!
    // swiftlint:enable implicitly_unwrapped_optional

    cancellable = publisher(
      forEvent: event,
      params: params,
      paywallOverrides: paywallOverrides
    )
    .sink(
      receiveCompletion: { _ in
        self.shared.presentationItems.cancellables.remove(cancellable)
      }, receiveValue: { state in
        paywallHandler?(state)
      }
    )

    cancellable.store(in: &shared.presentationItems.cancellables)
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

  /// Get the result of tracking an event.
  ///
  /// Use this function if you want to preemptively get the result of tracking
  /// an event.
  ///
  /// This is useful for when you want to know whether a particular event will
  /// present a paywall in the future.
  ///
  /// Note that this method does not present a paywall. To do that, use
  /// ``track(event:params:paywallOverrides:paywallHandler:)``.
  ///
  /// - Parameters:
  ///     - event: The name of the event you want to track.
  ///     - params: Optional parameters you'd like to pass with your event.
  ///
  /// - Returns: A ``TrackResult`` that indicates the result of tracking an event.
  static func getTrackResult(
    forEvent event: String,
    params: [String: Any]? = nil
  ) async -> TrackResult {
    let eventCreatedAt = Date()

    let trackableEvent = UserInitiatedEvent.Track(
      rawName: event,
      canImplicitlyTriggerPaywall: false,
      customParameters: params ?? [:]
    )

    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: trackableEvent,
      eventCreatedAt: eventCreatedAt
    )

    let eventData = EventData(
      name: event,
      parameters: JSON(parameters.eventParams),
      createdAt: eventCreatedAt
    )

    let presentationRequest = PresentationRequest(
      presentationInfo: .explicitTrigger(eventData)
    )

    return await getTrackResult(for: presentationRequest)
  }

  /// Get the result of tracking an event.
  ///
  /// Use this function if you want to preemptively get the result of tracking
  /// an event.
  ///
  /// This is useful for when you want to know whether a particular event will
  /// present a paywall in the future.
  ///
  /// Note that this method does not present a paywall. To do that, use
  /// ``track(event:params:paywallOverrides:paywallHandler:)``.
  ///
  /// - Parameters:
  ///     - event: The name of the event you want to track.
  ///     - params: Optional parameters you'd like to pass with your event.
  ///     - completion: A completion block that accepts a ``TrackResult`` indicating
  ///     the result of tracking an event.
  static func getTrackResult(
    forEvent event: String,
    params: [String: Any]? = nil,
    completion: @escaping (TrackResult) -> Void
  ) {
    Task {
      let result = await getTrackResult(forEvent: event, params: params)
      completion(result)
    }
  }

  /// Objective-C only function to get information about the result of tracking an event.
  ///
  /// Use this function if you want to preemptively get the result of tracking
  /// an event.
  ///
  /// This is useful for when you want to know whether a particular event will
  /// present a paywall in the future.
  ///
  /// Note that this method does not present a paywall. To do that, use
  /// ``track(event:params:products:ignoreSubscriptionStatus:presentationStyleOverride:onSkip:onPresent:onDismiss:)``.
  ///
  /// - Parameters:
  ///     - event: The name of the event you want to track.
  ///     - params: Optional parameters you'd like to pass with your event.
  ///
  /// - Returns: A ``TrackInfoObjc`` object that contains information about the result of tracking an event. 
  @available(swift, obsoleted: 1.0)
  @objc static func getTrackInfo(
    forEvent event: String,
    params: [String: Any]? = nil
  ) async -> TrackInfoObjc {
    let result = await getTrackResult(forEvent: event, params: params)
    return TrackInfoObjc(trackResult: result)
  }

  /// Converts dismissal result from enums with associated values, to old objective-c compatible way
  ///
  /// - Parameters:
  ///   - result: The dismissal result
  ///   - completion: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a ``PaywallInfo`` object containing information about the paywall.
  private static func onDismissConverter(
    _ result: PaywallDismissedResult,
    completion: (PaywallDismissedResultStateObjc, String?, PaywallInfo) -> Void
  ) {
    switch result.state {
    case .closed:
      completion(.closed, nil, result.paywallInfo)
    case .purchased(productId: let productId):
      completion(.purchased, productId, result.paywallInfo)
    case .restored:
      completion(.restored, nil, result.paywallInfo)
    }
  }

  private static func onSkipConverter(
    reason: PaywallSkippedReason,
    completion: ((PaywallSkippedReasonObjc, NSError) -> Void)?
  ) {
    switch reason {
    case .holdout(let experiment):
      let userInfo: [String: Any] = [
        "experimentId": experiment.id,
        "variantId": experiment.variant.id,
        "groupId": experiment.groupId,
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Holdout",
          value: "This user was assigned to a holdout. This means the paywall will not show.",
          comment: "ExperimentId: \(experiment.id), VariantId: \(experiment.variant.id), GroupId: \(experiment.groupId)"
        )
      ]
      let error = NSError(
        domain: "com.superwall",
        code: 4001,
        userInfo: userInfo
      )
      completion?(.holdout, error)
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
      completion?(.noRuleMatch, error)
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
      completion?(.eventNotFound, error)
    case .userIsSubscribed:
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "User Is Subscribed",
          value: "The value returned in the isUserSubscribed() delegate method is true. By default, paywalls do not show to users who are already subscribed. You can override this behavior in the paywall editor.",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "com.superwall",
        code: 4002,
        userInfo: userInfo
      )
      completion?(.userIsSubscribed, error)
    case .error(let error):
      completion?(.error, error as NSError)
    }
  }
}
