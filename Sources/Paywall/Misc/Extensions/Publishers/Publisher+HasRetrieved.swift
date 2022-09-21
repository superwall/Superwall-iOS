//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/09/2022.
//

import Combine

extension Publisher {
  @discardableResult
  func value() async -> Output {
    await self
      .compactMap { $0 }
      .eraseToAnyPublisher()
      .async()
  }
}
