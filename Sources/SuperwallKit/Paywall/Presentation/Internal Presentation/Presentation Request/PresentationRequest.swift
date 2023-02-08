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

  /// Overrides the default behavior and products of a paywall.
  var paywallOverrides: PaywallOverrides?

  struct Flags {
    var isDebuggerLaunched: Bool
    var userSubscriptionStatus: Published<SubscriptionStatus>.Publisher
    var isPaywallPresented: Bool
  }
  var flags: Flags

  unowned let dependencyContainer: DependencyContainer

  /// A `Just` publisher that that emits the request object once and finishes.
  var publisher: AnyPublisher<Self, Error> {
    Just(self)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }
}

extension PresentationRequest: Stubbable {
  static func stub() -> PresentationRequest {
    let dependencyContainer = DependencyContainer()
    return dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      paywallOverrides: nil,
      presentingViewController: nil,
      isDebuggerLaunched: false,
      isPaywallPresented: false
    )
  }
}
