//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation
import Combine

extension Superwall {
  /// Presents the paywall view controller, stores the presentation request for future use,
  /// and sends back a `presented` state to the paywall state publisher.
  ///
  /// - Parameters:
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A publisher that contains info for the next pipeline operator.
  func storePresentationObjects(
    request: PresentationRequest?,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>,
    featureGatingBehavior: FeatureGatingBehavior
  ) {
    guard let request = request else {
      return
    }
    let lastPaywallPresentation = LastPresentationItems(
      request: request,
      statePublisher: paywallStatePublisher,
      featureGatingBehavior: featureGatingBehavior
    )
    presentationItems.last = lastPaywallPresentation
  }
}
