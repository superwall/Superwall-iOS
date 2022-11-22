//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

extension AnyPublisher where Output == PresentationRequest, Failure == Error {
  /// Waits for the `IdentiyManager` to confim that the config has been received
  /// and the identity of the user has been established.
  func awaitIdentity() -> AnyPublisher<PresentationRequest, Failure> {
    return subscribe(on: DispatchQueue.global(qos: .userInitiated))
      .zip(IdentityManager.hasIdentity) { request, _ in
        return request
      }
      .eraseToAnyPublisher()
  }
}
