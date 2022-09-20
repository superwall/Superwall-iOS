//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/09/2022.
//

import Combine

enum AsyncError: Error {
  case finishedWithoutValue
}

extension AnyPublisher {
  /// Returns the first value of the publisher
  @discardableResult
  func async() async throws -> Output {
    try await withCheckedThrowingContinuation { continuation in
      var cancellable: AnyCancellable?
      var finishedWithoutValue = true
      cancellable = first()
        .sink { result in
          switch result {
          case .finished:
            if finishedWithoutValue {
              continuation.resume(throwing: AsyncError.finishedWithoutValue)
            }
          case let .failure(error):
            continuation.resume(throwing: error)
          }
          cancellable?.cancel()
        } receiveValue: { value in
          finishedWithoutValue = false
          continuation.resume(with: .success(value))
        }
    }
  }
}
