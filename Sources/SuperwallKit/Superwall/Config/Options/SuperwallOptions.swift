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
@objc public final class SuperwallOptions: NSObject {
  /// Configure the appearance and behaviour of paywalls.
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
}
