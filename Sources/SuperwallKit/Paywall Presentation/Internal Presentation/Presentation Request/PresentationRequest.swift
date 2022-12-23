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
    unowned let configManager: ConfigManager
    unowned let storage: Storage
    unowned let sessionEventsManager: SessionEventsManager
    unowned let paywallManager: PaywallManager
    unowned let superwall: Superwall = .shared
    let logger: Loggable.Type = Logger.self
    unowned let storeKitManager: StoreKitManager
    unowned let network: Network
    unowned let debugManager: DebugManager
    unowned let identityManager: IdentityManager
    unowned let deviceHelper: DeviceHelper
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
    let dependencyContainer = DependencyContainer(apiKey: "abc")
    return dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      paywallOverrides: nil,
      presentingViewController: nil,
      isDebuggerLaunched: false,
      isUserSubscribed: false,
      isPaywallPresented: false
    )
  }
}
