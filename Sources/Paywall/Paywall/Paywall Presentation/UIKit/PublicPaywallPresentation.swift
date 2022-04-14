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

	/// Presents a paywall to the user.
  ///
  /// For more information, see <doc:PresentingInUIKit>.
  ///
	/// - Parameters:
///     - onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo` object containing information about the paywall.
///     - onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo` object containing information about the paywall.
///    - onFail: A completion block that gets called when the paywall fails to present, either because an error occurred or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
	@objc static func present(
    onPresent: ((PaywallInfo) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo) -> Void)? = nil,
    onFail: ((NSError?) -> Void)? = nil
  ) {
    internallyPresent(
      onPresent: onPresent,
      onDismiss: { result in
        if let onDismiss = onDismiss {
          onDismissConverter(result, completion: onDismiss)
        }
      },
      onFail: onFail
    )
	}

	/// Presents a paywall to the user.
  ///
  /// For more information, see <doc:PresentingInUIKit>.
  ///
	/// - Parameters:
///     - on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
///     - onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a ``PaywallInfo``? object containing information about the paywall.
///     - onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a ``PaywallInfo``? object containing information about the paywall.
///     - onFail: A completion block that gets called when the paywall fails to present, either because an error occurred or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
  @objc static func present(
    on viewController: UIViewController? = nil,
    onPresent: ((PaywallInfo) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo) -> Void)? = nil,
    onFail: ((NSError?) -> Void)? = nil
  ) {
    internallyPresent(
      on: viewController,
      onPresent: onPresent,
      onDismiss: { result in
        if let onDismiss = onDismiss {
          onDismissConverter(result, completion: onDismiss)
        }
      },
      onFail: onFail
    )
	}

  /// Presents a paywall to the user.
  ///
  /// For more information, see <doc:PresentingInUIKit>.
  ///
  /// - Parameters:
  ///   - identifier: The identifier of the paywall you wish to present.
  ///   - on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
  ///   - ignoreSubscriptionStatus: Presents the paywall regardless of subscription status if `true`. Defaults to `false`.
  ///   - onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo` object containing information about the paywall.
  ///   - onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo` object containing information about the paywall.
  ///   - onFail: A completion block that gets called when the paywall fails to present, either because an error occurred or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
  @objc static func present(
    identifier: String? = nil,
    on viewController: UIViewController? = nil,
    ignoreSubscriptionStatus: Bool = false,
    onPresent: ((PaywallInfo) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo) -> Void)? = nil,
    onFail: ((NSError?) -> Void)? = nil
  ) {
    internallyPresent(
      withIdentifier: identifier,
      on: viewController,
      ignoreSubscriptionStatus: ignoreSubscriptionStatus,
      onPresent: onPresent,
      onDismiss: { result in
        if let onDismiss = onDismiss {
          onDismissConverter(result, completion: onDismiss)
        }
      },
      onFail: onFail
    )
  }

  /// Shows a specific paywall to the user when an analytics event you provide is tied to an active trigger in the [Superwall Dashboard](https://superwall.com/dashboard).
  ///
  /// Triggers enable you to retroactively decide where or when to show a specific paywall in your app. Use this method when you want to remotely control paywall presentation in response to your own analytics event and utilize completion handlers associated with the paywall presentation state.
  ///
  /// The paywall shown to the user is determined by the trigger associated with the event in the [Superwall Dashboard](https://superwall.com/dashboard).
  ///
  /// If you don't want to use any completion handlers, consider using ``Paywall/Paywall/track(_:_:)-2vkwo`` to implicitly trigger a paywall.
  ///
  /// For more information, see <doc:Triggering>.
  ///
  /// - Parameters:
  ///   -  event: The name of the event you wish to trigger (equivalent to event name in ``Paywall/Paywall/track(_:_:)-2vkwo``)
  ///   - params: Parameters you wish to pass along to the trigger (equivalent to params in `Paywall.track()`)
  ///   - on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
  ///   - ignoreSubscriptionStatus: Presents the paywall regardless of subscription status if `true`. Defaults to `false`.
  ///   - onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo` object containing information about the paywall.
  ///   - onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo` object containing information about the paywall.
  ///   - onSkip: A completion block that gets called when the paywall's presentation is skipped, either because the trigger is disabled or an error has occurred. Defaults to `nil`.  Accepts an `NSError?` with more details.
  @objc static func trigger(
    event: String? = nil,
    params: [String: Any]? = nil,
    on viewController: UIViewController? = nil,
    ignoreSubscriptionStatus: Bool = false,
    onSkip: ((NSError?) -> Void)? = nil,
    onPresent: ((PaywallInfo) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo) -> Void)? = nil
  ) {
    var eventData: EventData?

    if let name = event {
      eventData = Paywall.track(name, [:], params ?? [:], handleTrigger: false)
    }

    internallyPresent(
      on: viewController,
      fromEvent: eventData,
      ignoreSubscriptionStatus: ignoreSubscriptionStatus,
      onPresent: onPresent,
      onDismiss: { result in
        if let onDismiss = onDismiss {
          onDismissConverter(result, completion: onDismiss)
        }
      },
      onFail: onSkip
    )
  }

  /// Converts dismissal result from enums with associated values, to old objective-c compatible way
  ///
  /// - Parameters:
  ///   - result: The dismissal result
  ///   - completion: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo` object containing information about the paywall.
  private static func onDismissConverter(
    _ result: PaywallDismissalResult,
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
}
