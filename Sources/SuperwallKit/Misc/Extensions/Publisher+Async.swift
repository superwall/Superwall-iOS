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
  /// Returns on completion after getting the first value of the publisher, regardless
  /// of whether a value was returned or a failure occurred.
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

  /// Returns the first value of the publisher.
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
