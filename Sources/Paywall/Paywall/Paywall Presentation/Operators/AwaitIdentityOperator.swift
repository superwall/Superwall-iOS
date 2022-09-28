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
    return subscribe(on: DispatchQueue.global(qos: .userInitiated))
      .zip(IdentityManager.hasIdentity) { request, _ in
        return request
      }
      .eraseToAnyPublisher()
  }
}
