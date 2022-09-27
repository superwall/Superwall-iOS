//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/09/2022.
//

import Combine

extension Publisher {
  @discardableResult
  func hasValue<T>() async -> T where Output == T? {
    await self
      .compactMap { $0 }
      .eraseToAnyPublisher()
      .async()
  }
}

extension Publishers {
  static var readyToFireTriggers: AnyPublisher<Void, Never> {
    let hasConfig = ConfigManager.shared.$config
      .compactMap { $0 }

    let hasIdentity = IdentityManager.shared.hasIdentity
      .filter { $0 == true }
      .eraseToAnyPublisher()

    return hasConfig
      .zip(hasIdentity)
      .map { _ in
        return ()
      }
      .eraseToAnyPublisher()
  }
}
