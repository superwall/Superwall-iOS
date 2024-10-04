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
public final class SuperwallOptions: NSObject, Encodable {
  /// Configures the appearance and behaviour of paywalls.
  public var paywalls = PaywallOptions()

  /// **WARNING**:  The different network environments that the SDK should use.
  /// Only use this enum to set ``SuperwallOptions/networkEnvironment-swift.property``
  ///  if told so explicitly by the Superwall team.
  public enum NetworkEnvironment: Encodable, CustomStringConvertible {
    /// Default: Uses the standard latest environment.
    case release
    /// **WARNING**: Uses a release candidate environment. This is not meant for a production environment.
    case releaseCandidate
    /// **WARNING**: Uses the nightly build environment. This is not meant for a production environment.
    case developer
    /// **WARNING**: Uses a custom environment. This is not meant for a production environment.
    case custom(String)

    public var description: String {
      switch self {
      case .release:
        return "release"
      case .developer:
        return "developer"
      case .custom:
        return "custom"
      case .releaseCandidate:
        return "releaseCandidate"
      }
    }

    var scheme: String {
      switch self {
      case .custom(let domain):
        if let url = URL(string: domain) {
          return url.scheme ?? "https"
        }
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

    var geoHost: String {
      "geo-api.superwall.com"
    }

    var adServicesHost: String {
      "api-adservices.apple.com"
    }

    private enum CodingKeys: String, CodingKey {
      case networkEnvironment
      case customDomain
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      switch self {
      case .custom(let domain):
        try container.encode(domain, forKey: .customDomain)
      default:
        break
      }
      try container.encode(description, forKey: .networkEnvironment)
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

  /// Collects the `AdServices` attributes and attaches them to the user attributes.
  ///
  /// Defaults to `false`.
  public var collectAdServicesAttribution = false

  /// Configuration for printing to the console.
  @objc(SWKLogging)
  @objcMembers
  public final class Logging: NSObject, Encodable {
    /// Defines the minimum log level to print to the console. Defaults to `warn`.
    public var level: LogLevel = .info

    /// Defines the scope of logs to print to the console. Defaults to .all.
    public var scopes: Set<LogScope> = [.all]

    private enum CodingKeys: String, CodingKey {
      case logLevel
      case logScopes
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(level, forKey: .logLevel)
      try container.encode(scopes, forKey: .logScopes)
    }
  }
  /// The log scope and level to print to the console.
  public var logging = Logging()

  private enum CodingKeys: String, CodingKey {
    case isExternalDataCollectionEnabled
    case localeIdentifier
    case isGameControllerEnabled
    case collectAdServicesAttribution
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    // Manually encode PaywallOptions properties
    try paywalls.encode(to: encoder)
    try networkEnvironment.encode(to: encoder)
    try logging.encode(to: encoder)

    try container.encode(isExternalDataCollectionEnabled, forKey: .isExternalDataCollectionEnabled)
    try container.encode(localeIdentifier, forKey: .localeIdentifier)
    try container.encode(isGameControllerEnabled, forKey: .isGameControllerEnabled)
    try container.encode(collectAdServicesAttribution, forKey: .collectAdServicesAttribution)
  }

  func toDictionary() -> [String: Any] {
    guard let data = try? JSONEncoder().encode(self) else {
      return [:]
    }
    let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
    if let dictionary = jsonObject.flatMap({ $0 as? [String: Any] }) {
      return dictionary
    } else {
      return [:]
    }
  }
}
