//
//  SubscriptionsApiEnvironmentScript.swift
//  SuperwallKit
//

import Foundation

/// Tells paywall.js which subscriptions-api to call for web checkouts and teleports.
///
/// A native paywall is served from the same CDN host in every environment, so the
/// page cannot infer the environment from its own URL the way a hosted web paywall
/// can. Without this it falls back to production, which silently breaks a
/// `.developer` or `.local` SDK testing a checkout page against that stack.
enum SubscriptionsApiEnvironmentScript {
  /// The script source, or `nil` when the environment is production or unknown and
  /// paywall.js should keep its own default.
  static func source(for environment: SuperwallOptions.NetworkEnvironment) -> String? {
    let value: String
    switch environment {
    case .developer:
      value = "staging"
    case .local:
      value = "local"
    case .release, .releaseCandidate, .custom:
      return nil
    }
    return "window.__SW_SUBSCRIPTIONS_API_ENV__ = \"\(value)\";"
  }
}
