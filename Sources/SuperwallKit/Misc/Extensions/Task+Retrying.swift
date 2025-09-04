//
//  File.swift
//
//
//  Created by Yusuf Tör on 16/09/2022.
//
// Taken from: https://www.swiftbysundell.com/articles/retrying-an-async-swift-task/

import Foundation

extension Task where Failure == Error {
  /// Retries the given async operation up to `maxRetryCount` times if it throws.
  /// Supports optional retry intervals, exponential backoff, retry callbacks, and a timeout.
  /// Cancels all tasks once one completes or the timeout triggers.
  @discardableResult
  static func retrying(
    priority: TaskPriority? = nil,
    maxRetryCount: Int,
    retryInterval: Seconds? = nil,
    timeout: Seconds? = nil,
    isRetryingCallback: ((Int) -> Void)?,
    operation: @Sendable @escaping () async throws -> Success
  ) -> Task {
    Task(priority: priority) {
      try await withThrowingTaskGroup(of: Success.self) { group in
        group.addTask {
          for attempt in 0..<maxRetryCount {
            do {
              let result = try await operation()
              if let (_, response) = result as? (Data, URLResponse),
                let httpResponse = response as? HTTPURLResponse,
                !(200...299).contains(httpResponse.statusCode) {
                throw URLError(.badServerResponse)
              }
              return result
            } catch {
              isRetryingCallback?(attempt + 1)
              if let retryInterval = retryInterval {
                let oneSecond = TimeInterval(1_000_000_000)
                let nanoseconds = UInt64(oneSecond * retryInterval)
                try await Task<Never, Never>.sleep(nanoseconds: nanoseconds)
              } else if let delay = TaskRetryLogic.delay(
                forAttempt: attempt,
                maxRetries: maxRetryCount
              ) {
                try await Task<Never, Never>.sleep(nanoseconds: delay)
              }
              continue
            }
          }

          try Task<Never, Never>.checkCancellation()
          return try await operation()
        }

        if let timeout = timeout {
          group.addTask {
            try await Task<Never, Never>.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw _Concurrency.CancellationError()
          }
        }

        if let result = try await group.next() {
          group.cancelAll()
          return result
        } else {
          group.cancelAll()
          throw _Concurrency.CancellationError()
        }
      }
    }
  }
}

extension Task where Success == Void, Failure == Error {
  /// Retries the given async operation up to `maxRetryCount` times if it throws.
  /// Supports optional retry intervals, exponential backoff, retry callbacks, and a timeout.
  /// Cancels all tasks once one completes or the timeout triggers.
  @discardableResult
  static func retrying(
    priority: TaskPriority? = nil,
    maxRetryCount: Int,
    retryInterval: Seconds? = nil,
    timeout: Seconds? = nil,
    isRetryingCallback: ((Int) -> Void)? = nil,
    operation: @Sendable @escaping () async throws -> Void
  ) -> Task<Void, Error> {
    Task<Void, Error>(priority: priority) {
      try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          for attempt in 0..<maxRetryCount {
            do {
              try await operation()
              return
            } catch {
              isRetryingCallback?(attempt + 1)
              if let retryInterval = retryInterval {
                let oneSecond = TimeInterval(1_000_000_000)
                let nanoseconds = UInt64(oneSecond * retryInterval)
                try await Task<Never, Never>.sleep(nanoseconds: nanoseconds)
              } else if let delay = TaskRetryLogic.delay(
                forAttempt: attempt,
                maxRetries: maxRetryCount
              ) {
                try await Task<Never, Never>.sleep(nanoseconds: delay)
              }
              continue
            }
          }

          try Task<Never, Never>.checkCancellation()
          try await operation()
        }

        if let timeout = timeout {
          group.addTask {
            try await Task<Never, Never>.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw _Concurrency.CancellationError()
          }
        }

        _ = try await group.next()
        group.cancelAll()
      }
    }
  }
}
