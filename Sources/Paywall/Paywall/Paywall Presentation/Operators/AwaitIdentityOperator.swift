//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

extension AnyPublisher where Output == PaywallPresentationRequest, Failure == Error {
  func awaitIdentity() -> AnyPublisher<PaywallPresentationRequest, Failure> {
    let hasIdentityPublisher = IdentityManager.shared.hasIdentity
      .filter { $0 == true }
      .setFailureType(to: Error.self)

    return self
      .subscribe(on: DispatchQueue.global(qos: .userInitiated))
      .zip(hasIdentityPublisher) { request, hasIdentity in
        return request
      }
      .eraseToAnyPublisher()
  }
}
