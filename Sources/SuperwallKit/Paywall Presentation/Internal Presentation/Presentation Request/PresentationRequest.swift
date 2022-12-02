//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import UIKit
import Combine

/// Defines the information needed to request the presentation of a paywall.
struct PresentationRequest {
  /// The type of trigger (implicit/explicit/fromIdentifier), and associated data.
  let presentationInfo: PresentationInfo

  /// The view controller to present the paywall on, if any.
  var presentingViewController: UIViewController?

  /// Defines whether to retrieve the cached paywall. Defaults to `true`.
  var cached = true

  /// Overrides the default behavior and products of a paywall.
  var paywallOverrides: PaywallOverrides?

  struct Injections {
    var configManager: ConfigManager = .shared
    var storage: Storage = .shared
    var sessionEventsManager: SessionEventsManager = .shared
    var paywallManager: PaywallManager = .shared
    var superwall: Superwall = .shared
    let isDebuggerLaunched: Bool
    let isUserSubscribed: Bool
  }
  var injections: Injections

  /// A `Just` publisher that that emits the request object once and finishes.
  var publisher: AnyPublisher<Self, Error> {
    Just(self)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }
}
