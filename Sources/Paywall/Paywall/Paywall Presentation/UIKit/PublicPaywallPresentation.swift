//
//  File.swift
//  
//
//  Created by Jake Mor on 10/9/21.
//

import Foundation
import UIKit

public extension Paywall {
  /// Dismisses the presented paywall.
  ///
  /// Calling this function doesn't fire the `onDismiss` completion block in ``Paywall/Paywall/present(onPresent:onDismiss:onFail:)``, since this action is developer initiated.
	/// - Parameters:
  ///   - completion: An optional completion block that gets called after the paywall is dismissed. Defaults to nil.
	@objc static func dismiss(_ completion: (() -> Void)? = nil) {
		guard let paywallViewController = shared.paywallViewController else {
      return
    }
    shared.dismiss(
      paywallViewController,
      state: .closed,
      completion: completion
    )
	}

	/// Presents a paywall to the user. This method will be deprecated soon, we recommend using ``Paywall/Paywall/trigger(event:params:on:ignoreSubscriptionStatus:presentationStyleOverride:onSkip:onPresent:onDismiss:)`` for greater flexibility.
  ///
	/// - Parameters:
  ///     - onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a ``PaywallInfo``? object containing information about the paywall.
  ///     - onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a ``PaywallInfo``? object containing information about the paywall.
  ///    - onFail: A completion block that gets called when the paywall fails to present, either because an error occurred or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
  @available(*, deprecated, message: "Please use Paywall.trigger")
	@objc static func present(
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo?) -> Void)? = nil,
    onFail: ((NSError?) -> Void)? = nil
  ) {
    let trackableEvent = UserInitiatedEvent.DefaultPaywall()
    let result = Paywall.track(trackableEvent)
    let eventInfo = PresentationInfo.explicitTrigger(result.data)

    internallyPresent(
      eventInfo,
      onPresent: onPresent,
      onDismiss: { result in
        if let onDismiss = onDismiss {
          onDismissConverter(result, completion: onDismiss)
        }
      },
      onSkip: onFail
    )
	}

	/// Presents a paywall to the user. This method will be deprecated soon, we recommend using ``Paywall/Paywall/trigger(event:params:on:ignoreSubscriptionStatus:presentationStyleOverride:onSkip:onPresent:onDismiss:)`` for greater flexibility.
  ///
	/// - Parameters:
///     - on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
///     - onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a ``PaywallInfo``? object containing information about the paywall.
///     - onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a ``PaywallInfo``? object containing information about the paywall.
///     - onFail: A completion block that gets called when the paywall fails to present, either because an error occurred or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
  @available(*, deprecated, message: "Please use Paywall.trigger")
  @objc static func present(
    on viewController: UIViewController? = nil,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo?) -> Void)? = nil,
    onFail: ((NSError?) -> Void)? = nil
  ) {
    let trackableEvent = UserInitiatedEvent.DefaultPaywall()
    let result = Paywall.track(trackableEvent)
    let eventInfo = PresentationInfo.explicitTrigger(result.data)

    internallyPresent(
      eventInfo,
      on: viewController,
      onPresent: onPresent,
      onDismiss: { result in
        if let onDismiss = onDismiss {
          onDismissConverter(result, completion: onDismiss)
        }
      },
      onSkip: onFail
    )
	}

  /// Presents a paywall to the user. This method will be deprecated soon, we recommend using ``Paywall/Paywall/trigger(event:params:on:ignoreSubscriptionStatus:presentationStyleOverride:onSkip:onPresent:onDismiss:)`` for greater flexibility.
  ///
  /// - Parameters:
  ///   - identifier: The identifier of the paywall you wish to present.
  ///   - on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
  ///   - ignoreSubscriptionStatus: Presents the paywall regardless of subscription status if `true`. Defaults to `false`.
  ///   - presentationStyleOverride: A `PaywallPresentationStyle` object that overrides the presentation style of the paywall set on the dashboard. Defaults to `.none`.
  ///   - onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a ``PaywallInfo``? object containing information about the paywall.
  ///   - onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a ``PaywallInfo``? object containing information about the paywall.
  ///   - onFail: A completion block that gets called when the paywall fails to present, either because an error occurred or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
  @available(*, deprecated, message: "Please use Paywall.trigger")
  @objc static func present(
    identifier: String? = nil,
    on viewController: UIViewController? = nil,
    ignoreSubscriptionStatus: Bool = false,
    presentationStyleOverride: PaywallPresentationStyle = .none,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo?) -> Void)? = nil,
    onFail: ((NSError?) -> Void)? = nil
  ) {
    let presentationInfo: PresentationInfo
    if let identifier = identifier {
      presentationInfo = .fromIdentifier(identifier)
    } else {
      let trackableEvent = UserInitiatedEvent.DefaultPaywall()
      let result = Paywall.track(trackableEvent)
      presentationInfo = .explicitTrigger(result.data)
    }
    internallyPresent(
      presentationInfo,
      on: viewController,
      ignoreSubscriptionStatus: ignoreSubscriptionStatus,
      presentationStyleOverride: presentationStyleOverride,
      onPresent: onPresent,
      onDismiss: { result in
        if let onDismiss = onDismiss {
          onDismissConverter(result, completion: onDismiss)
        }
      },
      onSkip: onFail
    )
  }

  /// Shows a paywall to the user when: An analytics event you provide is tied to an active trigger inside a campaign on the [Superwall Dashboard](https://superwall.com/dashboard); the user matches a rule in the campaign; and a binding to a Boolean value that you provide is true.
  ///
  /// Triggers enable you to retroactively decide where or when to show a specific paywall in your app. Use this method when you want to remotely control paywall presentation in response to your own analytics event and utilize completion handlers associated with the paywall presentation state.
  ///
  /// Before using this method, you'll first need to create a campaign and add a trigger associated with the event name on the [Superwall Dashboard](https://superwall.com/dashboard).
  ///
  /// The paywall shown to the user is determined by the rules defined in the campaign. Paywalls are sticky, in that when a user is assigned a paywall within a rule, they will continue to see that paywall unless you remove the paywall from the rule.
  ///
  /// If you don't want to use any completion handlers, consider using ``Paywall/Paywall/track(_:_:)-2vkwo`` to implicitly trigger a paywall.
  ///
  /// For more information, see <doc:Triggering>.
  ///
  /// - Parameters:
  ///   -  event: The name of the event you wish to trigger (equivalent to event name in ``Paywall/Paywall/track(_:_:)-2vkwo``)
  ///   - params: Parameters you wish to pass along to the trigger (equivalent to params in ``Paywall/Paywall/track(_:_:)-2vkwo``). You can refer to these parameters in the rules you define in your campaign.
  ///   - on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
  ///   - ignoreSubscriptionStatus: Presents the paywall regardless of subscription status if `true`. Defaults to `false`.
  ///   - presentationStyleOverride: A `PaywallPresentationStyle` object that overrides the presentation style of the paywall set on the dashboard. Defaults to `.none`.
  ///   - onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a ``PaywallInfo``? object containing information about the paywall.
  ///   - onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a ``PaywallInfo``? object containing information about the paywall.
  ///   - onSkip: A completion block that gets called when the paywall's presentation is skipped. Defaults to `nil`.  Accepts an `NSError?` with more details. It is recommended to check the error code to handle the onSkip callback. If the error code is `4000`, it means the user didn't match any rules. If the error code is `4001` it means the user is in a holdout group. Otherwise, a `404` error code means an error occurred.
  @objc static func trigger(
    event: String? = nil,
    params: [String: Any]? = nil,
    on viewController: UIViewController? = nil,
    ignoreSubscriptionStatus: Bool = false,
    presentationStyleOverride: PaywallPresentationStyle = .none,
    onSkip: ((NSError?) -> Void)? = nil,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo?) -> Void)? = nil
  ) {
    let eventInfo: PresentationInfo
    if let name = event {
      let trackableEvent = UserInitiatedEvent.Track(
        rawName: name,
        canImplicitlyTriggerPaywall: false,
        customParameters: params ?? [:]
      )
      let result = Paywall.track(trackableEvent)
      eventInfo = .explicitTrigger(result.data)
    } else {
      let trackableEvent = UserInitiatedEvent.DefaultPaywall()
      let result = Paywall.track(trackableEvent)
      eventInfo = .explicitTrigger(result.data)
    }

    internallyPresent(
      eventInfo,
      on: viewController,
      ignoreSubscriptionStatus: ignoreSubscriptionStatus,
      presentationStyleOverride: presentationStyleOverride,
      onPresent: onPresent,
      onDismiss: { result in
        if let onDismiss = onDismiss {
          onDismissConverter(result, completion: onDismiss)
        }
      },
      onSkip: onSkip
    )
  }

  /// Converts dismissal result from enums with associated values, to old objective-c compatible way
  ///
  /// - Parameters:
  ///   - result: The dismissal result
  ///   - completion: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a ``PaywallInfo``? object containing information about the paywall.
  private static func onDismissConverter(
    _ result: PaywallDismissalResult,
    completion: (Bool, String?, PaywallInfo?) -> Void
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
}
