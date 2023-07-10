//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/10/2022.
//

import Foundation

/// Options for configuring the appearance and behavior of paywalls.
@objc(SWKPaywallOptions)
@objcMembers
public final class PaywallOptions: NSObject {
  /// Determines whether the paywall should use haptic feedback. Defaults to true.
  ///
  /// Haptic feedback occurs when a user purchases or restores a product, opens a URL
  /// from the paywall, or closes the paywall.
  public var isHapticFeedbackEnabled = true

  /// Defines the messaging of the alert presented to the user when restoring a transaction fails.

  @objc(SWKRestoreFailed)
  @objcMembers
  public final class RestoreFailed: NSObject {
    /// The title of the alert presented to the user when restoring a transaction fails. Defaults to
    /// `No Subscription Found`.
    public var title = "No Subscription Found"

    /// Defines the message of the alert presented to the user when restoring a transaction fails.
    /// Defaults to `We couldn't find an active subscription for your account.`
    public var message = "We couldn't find an active subscription for your account."

    /// Defines the title of the close button in the alert presented to the user when restoring a
    /// transaction fails. Defaults to `Okay`.
    public var closeButtonTitle = "Okay"
  }
  /// Defines the messaging of the alert presented to the user when restoring a transaction fails.
  public var restoreFailed = RestoreFailed()

  /// Shows an alert after a purchase fails. Defaults to `true`.
  ///
  /// Set this to `false` if you're using a `PurchaseController` and want to show
  /// your own alert after the purchase fails.
  public var shouldShowPurchaseFailureAlert = true

  /// Pre-loads and caches trigger paywalls and products when you initialize the SDK via ``Superwall/configure(apiKey:purchaseController:options:completion:)-52tke``. Defaults to `true`.
  ///
  /// Set this to `false` to load and cache paywalls and products in a just-in-time fashion.
  ///
  /// If you want to preload them at a later date, you can call ``Superwall/preloadAllPaywalls()``
  /// or ``Superwall/preloadPaywalls(forEvents:)``
  public var shouldPreload = true

  /// Automatically dismisses the paywall when a product is purchased or restored. Defaults to `true`.
  ///
  /// Set this to `false` to prevent the paywall from dismissing on purchase/restore.
  public var automaticallyDismiss = true

  /// Defines the different types of views that can appear behind Apple's payment sheet during a transaction.
  @objc(SWKTransactionBackgroundView)
  public enum TransactionBackgroundView: Int, Sendable {
    /// This shows your paywall background color overlayed with an activity indicator.
    case spinner

    /// Removes the background view during a transaction.
    case none
  }
  /// The view that appears behind Apple's payment sheet during a transaction. Defaults to `.spinner`.
  ///
  /// Set this to `.none` to remove the background view during a transaction.
  ///
  /// **Note:** This feature is still in development and could change.
  public var transactionBackgroundView: TransactionBackgroundView = .spinner
}
