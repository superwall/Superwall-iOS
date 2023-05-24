//
//  File.swift
//  
//
//  Created by Yusuf Tör on 24/05/2023.
//

import Foundation
import Combine

extension Superwall {
  /// This throws an error if there's no internet, the user isn't subscribed, and the paywall is gated.
  ///
  /// - Note: This doesn't send a state back to the paywall state publisher.
  func checkGatingAndInternet(
    from paywallInfo: PaywallInfo,
    request: PresentationRequest,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) async throws {
    if request.flags.hasInternet {
      return
    }
    let subscriptionStatus = await request.flags.subscriptionStatus.async()
    if subscriptionStatus == .active {
      return
    }
    switch paywallInfo.featureGatingBehavior {
    case .gated:
      paywallStatePublisher.send(completion: .finished)
      throw PresentationPipelineError.noInternet
    case .nonGated:
      return
    }
  }
}
