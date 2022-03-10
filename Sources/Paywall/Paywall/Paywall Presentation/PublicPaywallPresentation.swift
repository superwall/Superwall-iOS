//
//  File.swift
//  
//
//  Created by Jake Mor on 10/9/21.
//

import Foundation
import UIKit

public extension Paywall {
  /*// MARK: - Swift Only
  /// Presents a paywall to the user.
  ///  - Parameter on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
  ///  - Parameter onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo?` object containing information about the paywall.
  ///  - Parameter onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `PaywallDismissalResult` object. This has a `paywallInfo` property containing information about the paywall and a `state` that tells you why the paywall was dismissed. Defaults to `nil`.
  ///  - Parameter onFail: A completion block that gets called when the paywall fails to present, either because an error occured or because all paywalls are off. Accepts an `NSError?` with more details. Defaults to `nil`.
  static func present(
    on viewController: UIViewController? = nil,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((PaywallDismissalResult) -> Void)? = nil,
    onFail: ((NSError?) -> Void)? = nil
  ) {
    internallyPresent(
      on: viewController,
      onPresent: onPresent,
      onDismiss: onDismiss,
      onFail: onFail
    )
  }

  /// This function is equivalent to logging an event, but exposes completion blocks in case you would like to execute code based on specific outcomes
  ///  - Parameter event: The name of the event you wish to trigger (equivalent to event name in `Paywall.track()`).
  ///  - Parameter params: Parameters you wish to pass along to the trigger (equivalent to params in `Paywall.track()`).
  ///  - Parameter on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
  ///  - Parameter ignoreSubscriptionStatus: Presents the paywall regardless of subscription status if `true`. Defaults to `false`.
  ///  - Parameter onPresent: A completion block that gets called immediately after the paywall is presented.  Accepts a `PaywallInfo?` object containing information about the paywall. Defaults to `nil`.
  ///  - Parameter onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Accepts a `PaywallDismissalResult` object. This has a `paywallInfo` property containing information about the paywall and a `state` that tells you why the paywall was dismissed. Defaults to `nil`.
  ///  - Parameter onSkip: A completion block that gets called when the paywall's presentation is skipped, either because the trigger is disabled or an error has occurred. Defaults to `nil`.  Accepts an `NSError?` with more details.
  static func trigger(
    event: String? = nil,
    params: [String: Any]? = nil,
    on viewController: UIViewController? = nil,
    ignoreSubscriptionStatus: Bool = false,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((PaywallDismissalResult) -> Void)? = nil,
    onFail: ((NSError?) -> Void)? = nil
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
      onDismiss: onDismiss,
      onFail: onFail
    )
  }

  // MARK: - Objc & Swift*/
  /// Dismisses the presented paywall. Doesn't trigger a `PurchaseCompletionBlock` call if provided during `Paywall.present()`, since this action is developer initiated.
	/// - Parameter completion: A completion block of type `(()->())? = nil` that gets called after the paywall is dismissed.
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
	///  - Parameter onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onFail: A completion block that gets called when the paywall fails to present, either because an error occured or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
	@objc static func present(
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo?) -> Void)? = nil,
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
	///  - Parameter on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
	///  - Parameter onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo?` object containing information about the paywall.
	///  - Parameter onFail: A completion block that gets called when the paywall fails to present, either because an error occured or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
  @objc static func present(
    on viewController: UIViewController? = nil,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo?) -> Void)? = nil,
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
  ///  - Parameter identifier: The identifier of the paywall you wish to present
  ///  - Parameter on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
  ///  - Parameter ignoreSubscriptionStatus: Presents the paywall regardless of subscription status if `true`. Defaults to `false`.
  ///  - Parameter onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo?` object containing information about the paywall.
  ///  - Parameter onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo?` object containing information about the paywall.
  ///  - Parameter onFail: A completion block that gets called when the paywall fails to present, either because an error occured or because all paywalls are off. Defaults to `nil`.  Accepts an `NSError?` with more details.
  ///
  @objc static func present(
    identifier: String? = nil,
    on viewController: UIViewController? = nil,
    ignoreSubscriptionStatus: Bool = false,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo?) -> Void)? = nil,
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

  /// This function is equivalent to logging an event, but exposes completion blocks in case you would like to execute code based on specific outcomes
  ///  - Parameter event: The name of the event you wish to trigger (equivalent to event name in `Paywall.track()`)
  ///  - Parameter params: Parameters you wish to pass along to the trigger (equivalent to params in `Paywall.track()`)
  ///  - Parameter on: The view controller to present the paywall on. Adds a new window to present on if `nil`. Defaults to `nil`.
  ///  - Parameter ignoreSubscriptionStatus: Presents the paywall regardless of subscription status if `true`. Defaults to `false`.
  ///  - Parameter onPresent: A completion block that gets called immediately after the paywall is presented. Defaults to `nil`.  Accepts a `PaywallInfo?` object containing information about the paywall.
  ///  - Parameter onDismiss: A completion block that gets called when the paywall is dismissed by the user, by way of purchasing, restoring or manually dismissing. Defaults to `nil`. Accepts a `Bool` that is `true` if the user purchased a product and `false` if not, a `String?` equal to the product id of the purchased product (if any) and a `PaywallInfo?` object containing information about the paywall.
  ///  - Parameter onSkip: A completion block that gets called when the paywall's presentation is skipped, either because the trigger is disabled or an error has occurred. Defaults to `nil`.  Accepts an `NSError?` with more details.
  @objc static func trigger(
    event: String? = nil,
    params: [String: Any]? = nil,
    on viewController: UIViewController? = nil,
    ignoreSubscriptionStatus: Bool = false,
    onSkip: ((NSError?) -> Void)? = nil,
    onPresent: ((PaywallInfo?) -> Void)? = nil,
    onDismiss: ((Bool, String?, PaywallInfo?) -> Void)? = nil
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
