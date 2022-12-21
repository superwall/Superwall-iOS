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
    var configManager: ConfigManager
    var storage: Storage
    var sessionEventsManager: SessionEventsManager
    var paywallManager: PaywallManager
    var superwall: Superwall = .shared
    var logger: Loggable.Type = Logger.self
    var isDebuggerLaunched: Bool
    var isUserSubscribed: Bool
    var isPaywallPresented: Bool
  }
  var injections: Injections

  /// A `Just` publisher that that emits the request object once and finishes.
  var publisher: AnyPublisher<Self, Error> {
    Just(self)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }
}

extension PresentationRequest: Stubbable {
  static func stub() -> PresentationRequest {
    let storage = Storage()
    let paywallManager = PaywallManager()
    let network = Network()
    let configManager = ConfigManager(
      options: nil,
      storage: storage,
      network: network,
      paywallManager: paywallManager
    )
    let appSessionManager = AppSessionManager(configManager: configManager)

    return PresentationRequest(
      presentationInfo: .explicitTrigger(.stub()),
      injections: .init(
        configManager: configManager,
        storage: storage,
        sessionEventsManager: SessionEventsManager(
          storage: storage,
          network: network,
          configManager: configManager,
          appSessionManager: appSessionManager,
          identityManager: IdentityManager(storage: storage, configManager: configManager)
        ),
        paywallManager: paywallManager,
        isDebuggerLaunched: false,
        isUserSubscribed: false,
        isPaywallPresented: false
      )
    )
  }
}
