//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import UIKit
import Combine

enum PresentationRequestType: Equatable, CustomStringConvertible {
  /// Presenting via ``Superwall/register(event:params:handler:feature:)``.
  case presentation

  /// Getting the paywall view controller via
  /// ``Superwall/getPaywall(forEvent:params:paywallOverrides:delegate:)``.
  case getPaywallViewController(PaywallViewControllerDelegateAdapter)

  /// Getting the presentation result via ``Superwall/getPresentationResult(forEvent:)``
  case getPresentationResult

  /// Getting the presentation result from an event that's used internally. Specifically, getting the result
  /// of calling `paywall_decline`.
  case getImplicitPresentationResult

  var description: String {
    switch self {
    case .presentation:
      return "presentation"
    case .getPaywallViewController:
      return "getPaywallViewController"
    case .getPresentationResult:
      return "getPresentationResult"
    case .getImplicitPresentationResult:
      return "getImplicitPresentationResult"
    }
  }

  func getPaywallVcDelegateAdapter() -> PaywallViewControllerDelegateAdapter? {
    switch self {
    case .getPaywallViewController(let adapter):
      return adapter
    default:
      return nil
    }
  }

  func hasObjcDelegate() -> Bool {
    switch self {
    case .getPaywallViewController(let adapter):
      return adapter.hasObjcDelegate
    default:
      return false
    }
  }

  static func == (lhs: PresentationRequestType, rhs: PresentationRequestType) -> Bool {
    switch (lhs, rhs) {
    case (.getImplicitPresentationResult, .getImplicitPresentationResult),
      (.getPresentationResult, .getPresentationResult),
      (.presentation, .presentation),
      (.getPaywallViewController, .getPaywallViewController):
      return true
    default:
      return false
    }
  }
}

/// Defines the information needed to request the presentation of a paywall.
struct PresentationRequest {
  /// The type of trigger (implicit/explicit/fromIdentifier), and associated data.
  let presentationInfo: PresentationInfo

  /// The view controller to present the paywall on, if any.
  var presenter: UIViewController?

  /// Overrides the default behavior and products of a paywall.
  var paywallOverrides: PaywallOverrides?

  struct Flags {
    var isDebuggerLaunched: Bool
    var subscriptionStatus: AnyPublisher<SubscriptionStatus, Never>
    var isPaywallPresented: Bool
    var type: PresentationRequestType
  }
  var flags: Flags

  /// A `Just` publisher that that emits the request object once and finishes.
  var publisher: AnyPublisher<Self, Error> {
    Just(self)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }
}

extension PresentationRequest: Stubbable {
  // Note: If making a stub in a test and needing to change things like
  // configManager, this may not work because the original one will be
  // deallocated and cause a crash. You'll need to create the request yourself.
  static func stub() -> PresentationRequest {
    let dependencyContainer = DependencyContainer()
    return dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      paywallOverrides: nil,
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .presentation
    )
  }
}
