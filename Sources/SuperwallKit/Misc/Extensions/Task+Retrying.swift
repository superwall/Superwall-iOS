//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/09/2022.
//
// Taken from: https://www.swiftbysundell.com/articles/retrying-an-async-swift-task/

import Foundation

extension Task where Failure == Error {
  @discardableResult
  static func retrying(
    priority: TaskPriority? = nil,
    maxRetryCount: Int,
    operation: @Sendable @escaping () async throws -> Success,
    isRetryingHandler: ((Bool) -> Void)? = nil
  ) -> Task {
    Task(priority: priority) {
      for attempt in 0..<maxRetryCount {
        do {
          let result = try await operation()
          isRetryingHandler?(false)
          return result
        } catch {
          isRetryingHandler?(true)
          guard let delay = TaskRetryLogic.delay(
            forAttempt: attempt,
            maxRetries: maxRetryCount
          ) else {
            break
          }
          try await Task<Never, Never>.sleep(nanoseconds: delay)

          continue
        }
      }

      try Task<Never, Never>.checkCancellation()
      isRetryingHandler?(false)
      return try await operation()
    }
  }
}
