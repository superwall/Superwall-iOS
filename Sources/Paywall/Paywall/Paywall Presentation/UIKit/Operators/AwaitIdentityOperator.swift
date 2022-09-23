//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

extension AnyPublisher where Output == PaywallPresentationRequest, Failure == Error {
  func awaitIdentity() -> AnyPublisher<PaywallPresentationRequest), Failure> {
    self
      .subscribe(on: DispatchQueue.global(qos: .userInitiated))
      .zip(IdentityManager.shared.$hasIdentity.isTrue()) { request, hasIdentity in
        return request
      }
      .eraseToAnyPublisher()
  }
}
