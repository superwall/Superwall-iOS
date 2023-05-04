//
//  File.swift
//  
//
//  Created by Jake Mor on 10/9/21.
//

import Foundation
import Combine
import UIKit

extension Superwall {
  // MARK: - Dismiss
  /// Dismisses the presented paywall.
  /// 
	/// - Parameter completion: An optional completion block that gets called after the paywall is dismissed.
  /// Defaults to `nil`.
  @objc public func dismiss(completion: (() -> Void)? = nil) {
    Task { [weak self] in
      await self?.dismiss()
      completion?()
    }
  }

  /// Objective-C-only method. Dismisses the presented paywall.
  @available(swift, obsoleted: 1.0)
  @objc public func dismiss() {
    Task { [weak self] in
      await self?.dismiss()
    }
  }

  /// Dismisses the presented paywall.
  @MainActor
  @nonobjc
  public func dismiss() async {
    guard let paywallViewController = paywallViewController else {
      return
    }
    await withCheckedContinuation { continuation in
      dismiss(
        paywallViewController,
        result: .closed
      ) {
        continuation.resume()
      }
    }
  }

  @MainActor
  func dismissForNextPaywall() async {
    guard let paywallViewController = paywallViewController else {
      return
    }

    await withCheckedContinuation { continuation in
      dismiss(
        paywallViewController,
        result: .closed,
        shouldCompleteStatePublisher: false,
        closeReason: .forNextPaywall
      ) {
        continuation.resume()
      }
    }
  }

  // MARK: - Register

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
  ///   - handler: An optional handler whose variables provide status updates for a paywall. Defaults to `nil`.
  ///   - feature: A completion block containing a feature that you wish to paywall. Access to this block is remotely configurable via the [Superwall Dashboard](https://superwall.com/dashboard). If the paywall is set to _Non Gated_, this will be called when the paywall is dismissed or if the user is already paying. If the paywall is _Gated_, this will be called only if the user is already paying or if they begin paying. If no paywall is configured, this gets called immediately. This will not be called in the event of an error, which you can detect via the `handler`.
  public func register(
    event: String,
    params: [String: Any]? = nil,
    handler: PaywallPresentationHandler? = nil,
    feature: @escaping () -> Void
  ) {
    internallyRegister(event: event, params: params, handler: handler, feature: feature)
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
  ///   - handler: An optional handler whose variables provide status updates for a paywall. Defaults to `nil`.
  public func register(
    event: String,
    params: [String: Any]? = nil,
    handler: PaywallPresentationHandler? = nil
  ) {
    internallyRegister(event: event, params: params, handler: handler)
  }

  private func internallyRegister(
    event: String,
    params: [String: Any]? = nil,
    handler: PaywallPresentationHandler? = nil,
    feature completion: (() -> Void)? = nil
  ) {
    publisher(
      forEvent: event,
      params: params,
      paywallOverrides: nil,
      isFeatureGatable: completion != nil
    )
    .subscribe(Subscribers.Sink(
      receiveCompletion: { _ in },
      receiveValue: { [weak self] state in
        guard let self = self else {
          return
        }
        switch state {
        case .presented(let paywallInfo):
            handler?.onPresentHandler?(paywallInfo)
        case let .dismissed(paywallInfo, state):
            handler?.onDismissHandler?(paywallInfo)
          switch state {
          case .purchased,
            .restored:
            completion?()
          case .closed:
            let closeReason = paywallInfo.closeReason
            let featureGating = paywallInfo.featureGatingBehavior
            if closeReason != .forNextPaywall && featureGating == .nonGated {
              completion?()
            }
          }
        case .skipped(let reason):
          if let handler = handler?.onSkipHandler {
            handler(reason)
          } else {
            let objcReason = self.onSkipConverter(reason: reason)
            handler?.onSkipHandlerObjc?(objcReason)
          }
        case .presentationError(let error):
          handler?.onErrorHandler?(error) // otherwise turning internet off would give unlimited access
        }
      }
    ))
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
  @objc public func register(event: String) {
    internallyRegister(event: event)
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
  @objc public func register(
    event: String,
    params: [String: Any]?
  ) {
    internallyRegister(event: event, params: params)
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
  public func publisher(
    forEvent event: String,
    params: [String: Any]? = nil,
    paywallOverrides: PaywallOverrides? = nil,
    isFeatureGatable: Bool
  ) -> PaywallStatePublisher {
    do {
      try TrackingLogic.checkNotSuperwallEvent(event)
    } catch {
      return Just(.presentationError(error)).eraseToAnyPublisher()
    }

    return Future {
      let trackableEvent = UserInitiatedEvent.Track(
        rawName: event,
        canImplicitlyTriggerPaywall: false,
        customParameters: params ?? [:],
        isFeatureGatable: isFeatureGatable
      )
      let trackResult = await self.track(trackableEvent)
      return (trackResult, self.isPaywallPresented)
    }
    .flatMap { trackResult, isPaywallPresented in
      let presentationRequest = self.dependencyContainer.makePresentationRequest(
        .explicitTrigger(trackResult.data),
        paywallOverrides: paywallOverrides,
        isPaywallPresented: isPaywallPresented,
        type: .presentation
      )
      return self.internallyPresent(presentationRequest)
    }
    .eraseToAnyPublisher()
  }

  private func onSkipConverter(reason: PaywallSkippedReason) -> PaywallSkippedReasonObjc {
    switch reason {
    case .holdout:
      return .holdout
    case .noRuleMatch:
      return .noRuleMatch
    case .eventNotFound:
      return .eventNotFound
    case .userIsSubscribed:
      return .userIsSubscribed
    }
  }
}
