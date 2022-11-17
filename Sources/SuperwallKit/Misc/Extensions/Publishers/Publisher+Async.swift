//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/09/2022.
//
// https://medium.com/geekculture/from-combine-to-async-await-c08bf1d15b77

import Combine

enum AsyncError: Error {
  case finishedWithoutValue
}

extension Publisher {
  /// Waits for the first value of the publisher.
  func asyncNoValue() async {
    _ = await withCheckedContinuation { continuation in
      var cancellable: AnyCancellable?
      cancellable = first()
        .sink(
          receiveCompletion: { _ in
            continuation.resume()
            cancellable?.cancel()
          },
          receiveValue: { _ in }
        )
    }
  }

  /// Waits and returns the first value of the publisher.
  @discardableResult
  func async() async -> Output {
    await withCheckedContinuation { continuation in
      var cancellable: AnyCancellable?
      cancellable = first()
        .sink { _ in
          cancellable?.cancel()
        } receiveValue: { value in
          continuation.resume(with: .success(value))
        }
    }
  }

  /// Returns the first value of the publisher
  @discardableResult
  func throwableAsync() async throws -> Output {
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
