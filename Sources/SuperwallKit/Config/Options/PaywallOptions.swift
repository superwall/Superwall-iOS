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

  /// Pre-loads and caches trigger paywalls and products when you initialize the SDK via ``Superwall/configure(apiKey:delegate:options:completion:)-7fafw``. Defaults to `true`.
  ///
  /// Set this to `false` to load and cache paywalls and products in a just-in-time fashion.
  ///
  /// If you want to preload them at a later date, you can call ``SuperwallKit/Superwall/preloadAllPaywalls()``
  /// or ``SuperwallKit/Superwall/preloadPaywalls(forEvents:)``
  public var shouldPreload = true

  /// Loads paywall template websites from disk, if available. Defaults to `true`.
  ///
  /// When you save a change to your paywall in the Superwall dashboard, a key is
  /// appended to the end of your paywall website URL, e.g. `sw_cache_key=<Date saved>`.
  /// This is used to cache your paywall webpage to disk after it's first loaded. Superwall will
  /// continue to load the cached version of your paywall webpage unless the next time you
  /// make a change on the Superwall dashboard.
  var useCachedTemplates = false

  /// Automatically dismisses the paywall when a product is purchased or restored. Defaults to `true`.
  ///
  /// Set this to `false` to prevent the paywall from dismissing on purchase/restore.
  public var automaticallyDismiss = true

  /// Defines the different types of views that can appear behind Apple's payment sheet during a transaction.

  @objc(SWKTransactionBackgroundView)
  public enum TransactionBackgroundView: Int, Sendable {
    /// This shows your paywall background color overlayed with an activity indicator.
    case spinner
  }
  /// The view that appears behind Apple's payment sheet during a transaction. Defaults to `.spinner`.
  ///
  /// Set this to `nil` to remove any background view during the transaction.
  ///
  /// **Note:** This feature is still in development and is likely to change.
  public var transactionBackgroundView: TransactionBackgroundView? = .spinner
}
