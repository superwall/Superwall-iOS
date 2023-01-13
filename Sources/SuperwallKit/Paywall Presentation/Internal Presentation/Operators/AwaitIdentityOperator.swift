//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

extension AnyPublisher where Output == PresentationRequest, Failure == Error {
  /// Waits for the `IdentiyManager` to confirm that the config has been received
  /// and the identity of the user has been established.
  func awaitIdentity() -> AnyPublisher<PresentationRequest, Failure> {
    subscribe(on: DispatchQueue.global(qos: .userInitiated))
      .flatMap { request in
        zip(request.injections.identityManager.hasIdentity)
      }
      .map { request, _ in
        return request
      }
      .eraseToAnyPublisher()
  }
}
