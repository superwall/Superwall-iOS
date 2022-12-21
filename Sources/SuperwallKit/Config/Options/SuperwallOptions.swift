//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/07/2022.
//

import Foundation

/// Options for configuring Superwall, including paywall presentation and appearance.
///
/// Pass an instance of this class to ``SuperwallKit/Superwall/configure(apiKey:delegate:options:)-7doe5``.
@objc(SWKSuperwallOptions)
@objcMembers
public final class SuperwallOptions: NSObject {
  /// Configures the appearance and behaviour of paywalls.
  public var paywalls = PaywallOptions()

  /// WARNING: Only use this enum to set `Superwall.networkEnvironment` if told so explicitly by the Superwall team.
  public enum PaywallNetworkEnvironment {
    /// Default: Use the standard latest environment.
    case release
    /// WARNING: Use a release candidate environment.
    case releaseCandidate
    /// WARNING: Use the nightly build environment.
    case developer
  }
  ///  **WARNING:** Determines which network environment your SDK should use. Defaults to `.release`. You should under no circumstance change this unless you received the go-ahead from the Superwall team.
  public var networkEnvironment: PaywallNetworkEnvironment = .release

  /// Forwards events from the game controller to the paywall. Defaults to `false`.
  ///
  /// Set this to `true` to forward events from the Game Controller to the Paywall via ``SuperwallKit/Superwall/gamepadValueChanged(gamepad:element:)``.
  public var isGameControllerEnabled = false

  /// Configuration for printing to the console.
  public struct Logging {
    /// Defines the minimum log level to print to the console. Defaults to `warn`.
    public var level: LogLevel? = .warn

    /// Defines the scope of logs to print to the console. Defaults to .all.
    public var scopes: Set<LogScope> = [.all]
  }
  /// The log scope and level to print to the console.
  public var logging = Logging()

  // TODO: Maybe make it more explicit that this is false when haspurchasingDelegate:
  /// Tells the SDK whether to finish transactions for products purchased on the paywall.
  /// Defaults to `true`. **If this is `false` you must finish transactions yourself.**
  ///
  /// By default, Superwall finishes all transactions. This is because it handles all the
  /// purchasing logic for paywalls, using StoreKit 2 when available. Setting this to
  /// `false` will make Superwall use StoreKit 1 and won't finish any transactions.
  ///
  /// This is useful in the following scenarios:
  ///
  /// - Purchasing with RevenueCat outside of Superwall.
  /// Make sure to set `usesStoreKit2IfAvailable` to `false` and do not use
  /// Observer Mode when configuring the RevenueCat SDK.
  /// This way RevenueCat will detect and finish all transactions on device for you and there will
  /// be no interference between SDKs:
  /// ```
  /// Purchases.configure(
  ///   with: .init(withAPIKey: revenueCatApiKey)
  ///     .with(usesStoreKit2IfAvailable: false)
  /// )
  /// ```
  /// - Purchasing using StoreKit outside of Superwall. You must only use StoreKit 1 and you
  /// must finish the transactions.
  public var finishTransactions = true
}
