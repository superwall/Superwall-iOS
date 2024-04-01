//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/07/2022.
//

import Foundation

/// Options for configuring Superwall, including paywall presentation and appearance.
///
/// Pass an instance of this class to
/// ``Superwall/configure(apiKey:purchaseController:options:completion:)-52tke``.
@objc(SWKSuperwallOptions)
@objcMembers
public final class SuperwallOptions: NSObject {
  /// Configures the appearance and behaviour of paywalls.
  public var paywalls = PaywallOptions()

  /// **WARNING**:  The different network environments that the SDK should use.
  /// Only use this enum to set ``SuperwallOptions/networkEnvironment-swift.property``
  ///  if told so explicitly by the Superwall team.
  public enum NetworkEnvironment {
    /// Default: Uses the standard latest environment.
    case release
    /// **WARNING**: Uses a release candidate environment. This is not meant for a production environment.
    case releaseCandidate
    /// **WARNING**: Uses the nightly build environment. This is not meant for a production environment.
    case developer
		/// **WARNING**: Uses a custom environment. This is not meant for a production environment.
    case custom(String)

    var scheme: String {
      switch self {
        case .custom(let domain):
        if let url = URL(string: domain) {
          return url.scheme ?? "https"
        }
          break
      default:
        return "https"
      }
    return "https"
    }

      var port: Int? {
          switch self {
          case .custom(let domain):
              if let url = URL(string: domain) {
                  return url.port
              }
          default:
              return nil
          }
          return nil
      }

    var hostDomain: String {
        switch self {
        case .release:
            return "superwall.me"
        case .releaseCandidate:
            return "superwallcanary.com"
        case .developer:
            return "superwall.dev"
        case .custom(let domain):
            if let url = URL(string: domain) {
                if let host = url.host {
                    return host
                }
            }
            return domain
        }
    }

    var baseHost: String {
        switch self {
        case .custom:

            return hostDomain
        default:
            return "api.\(hostDomain)"
        }
    }

    var collectorHost: String {
        switch self {
        case .custom:
            return hostDomain
        default:
            return "collector.\(hostDomain)"
        }
    }
  }

  /// **WARNING:**: Determines which network environment your SDK should use.
  /// Defaults to `.release`.  You should under no circumstance change this unless you
  /// received the go-ahead from the Superwall team.
  public var networkEnvironment: NetworkEnvironment = .release

  /// Enables the sending of non-Superwall tracked events and properties back to the Superwall servers.
  /// Defaults to `true`.
  ///
  /// Set this to `false` to stop external data collection. This will not affect
  /// your ability to create triggers based on properties.
  public var isExternalDataCollectionEnabled = true

  /// Sets the device locale identifier to use when evaluating rules.
  ///
  /// This defaults to the `autoupdatingCurrent` locale identifier. However, you can set
  /// this to any locale identifier to override it. E.g. `en_GB`. This is typically used for testing
  /// purposes.
  ///
  /// You can also preview your paywall in different locales using
  /// [In-App Previews](https://docs.superwall.com/docs/in-app-paywall-previews).
  public var localeIdentifier: String?

  /// Forwards events from the game controller to the paywall. Defaults to `false`.
  ///
  /// Set this to `true` to forward events from the Game Controller to the Paywall via ``Superwall/gamepadValueChanged(gamepad:element:)``.
  public var isGameControllerEnabled = false

  /// Configuration for printing to the console.
  @objc(SWKLogging)
  @objcMembers
  public final class Logging: NSObject {
    /// Defines the minimum log level to print to the console. Defaults to `warn`.
    public var level: LogLevel = .info

    /// Defines the scope of logs to print to the console. Defaults to .all.
    public var scopes: Set<LogScope> = [.all]
  }
  /// The log scope and level to print to the console.
  public var logging = Logging()
}
