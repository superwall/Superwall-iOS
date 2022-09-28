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
