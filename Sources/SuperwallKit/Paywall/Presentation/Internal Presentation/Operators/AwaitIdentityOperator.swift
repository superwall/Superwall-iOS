//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

extension AnyPublisher where Output == PresentationRequest, Failure == Error {
  /// Waits for config to be received and the identity and subscription status of the user to
  /// be established.
  func waitToPresent() -> AnyPublisher<PresentationRequest, Failure> {
    subscribe(on: DispatchQueue.global(qos: .userInitiated))
  // TODO: PRINT OUT HERE
      .flatMap { request in
        zip(
          request.dependencyContainer.identityManager.hasIdentity,
          request.dependencyContainer.configManager.hasConfig,
          request.flags.subscriptionStatus
            .filter { $0 != .unknown }
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
        )
      }
      .first()
      .map { request, _, _, _ in
        Logger.debug(
          logLevel: .info,
          scope: .paywallPresentation,
          message: "Retrieved identity, configuration and subscription status."
        )
        return request
      }
      .eraseToAnyPublisher()
  }
}
