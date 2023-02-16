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
        return request
      }
      .eraseToAnyPublisher()
  }
}
