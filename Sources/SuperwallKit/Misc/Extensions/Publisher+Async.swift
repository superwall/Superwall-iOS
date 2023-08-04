//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/09/2022.
//
// https://medium.com/geekculture/from-combine-to-async-await-c08bf1d15b77

import Combine

extension Publisher {
  /// Returns the first value of the publisher, throwing on failure or if no value was returned.
  @discardableResult
  func throwableAsync() async throws -> Output {
    for try await value in values {
      return value
    }
    throw CancellationError()
  }

  /// Convert this publisher into an `AsyncThrowingStream` that
  /// can be iterated over asynchronously using `for try await`.
  /// The stream will yield each output value produced by the
  /// publisher and will finish once the publisher completes.
  var values: AsyncThrowingStream<Output, Error> {
    AsyncThrowingStream { continuation in
      var cancellable: AnyCancellable?
      let onTermination = { cancellable?.cancel() }

      continuation.onTermination = { @Sendable _ in
        onTermination()
      }

      cancellable = sink(
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            continuation.finish()
          case .failure(let error):
            continuation.finish(throwing: error)
          }
        }, receiveValue: { value in
          continuation.yield(value)
        }
      )
    }
  }
}
