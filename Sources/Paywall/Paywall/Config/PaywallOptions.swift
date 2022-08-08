//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/07/2022.
//

import Foundation

/// Options for configuring the appearance and behavior of the paywall.
///
/// Pass an instance of this class to ``Paywall/Paywall/configure(apiKey:userId:delegate:options:)`` to override the default paywall appearance and behavior.
public class PaywallOptions: NSObject {
  /// Determines whether the paywall should use haptic feedback. Defaults to true.
  ///
  /// Haptic feedback occurs when a user purchases or restores a product, opens a URL from the paywall, or closes the paywall.
  public var isHapticFeedbackEnabled = true

  /// Defines the messaging of the alert presented to the user when restoring a transaction fails.
  public struct RestoreFailed {
    /// The title of the alert presented to the user when restoring a transaction fails. Defaults to `No Subscription Found`.
    public var title = "No Subscription Found"

    /// Defines the message of the alert presented to the user when restoring a transaction fails. Defaults to `We couldn't find an active subscription for your account.`
    public var message = "We couldn't find an active subscription for your account."

    /// Defines the title of the close button in the alert presented to the user when restoring a transaction fails. Defaults to `Okay`.
    public var closeButtonTitle = "Okay"
  }
  /// Defines the messaging of the alert presented to the user when restoring a transaction fails.
  public var restoreFailed = RestoreFailed()

  /// WARNING: Only use this enum to set `Paywall.networkEnvironment` if told so explicitly by the Superwall team.
  public enum PaywallNetworkEnvironment {
    /// Default: Use the standard latest environment
    case release
    /// WARNING: Use a release candidate environment
    case releaseCandidate
    /// WARNING: Use the nightly build environment
    case developer
  }
  ///  **WARNING:** Determines which network environment your SDK should use. Defaults to `.release`. You should under no circumstance change this unless you received the go-ahead from the Superwall team.
  public var networkEnvironment: PaywallNetworkEnvironment = .release

  /// Forwards events from the game controller to the paywall. Defaults to `false`.
  ///
  /// Set this to `true` to forward events from the Game Controller to the Paywall via ``Paywall/Paywall/gamepadValueChanged(gamepad:element:)``.
  public var isGameControllerEnabled = false

  /// Pre-loads and caches trigger paywalls and products when you initialize the SDK via ``Paywall/Paywall/configure(apiKey:userId:delegate:options:)``. Defaults to `true`.
  ///
  /// Set this to `false` to load and cache paywalls and products in a just-in-time fashion.
  public var shouldPreloadPaywalls = true

  /// Loads paywall template websites from disk, if available. Defaults to `true`.
  ///
  /// When you save a change to your paywall in the Superwall dashboard, a key is appended to the end of your paywall website URL, e.g. `sw_cache_key=<Date saved>`. This is used to cache your paywall webpage to disk after it's first loaded. Superwall will continue to load the cached version of your paywall webpage unless the next time you make a change on the Superwall dashboard.
  public var useCachedPaywallTemplates = true

  /// Configuration for printing to the console.
  public struct Logging {
    /// Defines the minimum log level to print to the console. Defaults to `warn`.
    public var level: LogLevel? = .warn

    /// Defines the scope of logs to print to the console. Defaults to .all
    public var scopes: Set<LogScope> = [.all]
  }
  /// The log scope and level to print to the console.
  public var logging = Logging()

  /// Automatically dismisses the paywall when a product is purchased or restored. Defaults to `true`.
  ///
  /// Set this to `false` to prevent the paywall from dismissing on purchase/restore.
  public var automaticallyDismiss = true

  /// Defines the different types of views that can appear behind Apple's payment sheet during a transaction.
  public enum TransactionBackgroundView {
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
