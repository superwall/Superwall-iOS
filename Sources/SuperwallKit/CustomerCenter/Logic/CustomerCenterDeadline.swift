//
//  CustomerCenterDeadline.swift
//
//
//  Created by Yusuf Tör on 15/10/2026.
//

import Foundation

/// Stops waiting on a task that's taking too long, without waiting for the task to stop.
///
/// A task group can't do this on its own: it waits for every child before it returns, so a child
/// that ignores cancellation — a network request awaiting its retry schedule in a task of its
/// own — keeps the group open until it finishes, however early the timer fired.
enum CustomerCenterDeadline {
  /// The value of `task` if it finishes within `seconds`, otherwise `nil`.
  ///
  /// `task` isn't cancelled and carries on, so a caller that gives up waiting can still pick up
  /// its value later.
  static func value<T>(of task: Task<T, Error>, within seconds: TimeInterval) async throws -> T? {
    try await race(seconds) { try await task.value }
  }

  /// The value of `task` if it finishes within `seconds`, otherwise `nil`.
  ///
  /// `task` isn't cancelled and carries on, so a caller that gives up waiting can still pick up
  /// its value later.
  static func value<T>(of task: Task<T, Never>, within seconds: TimeInterval) async -> T? {
    // Can't throw: the only thing that could is `task`, and it can't.
    try? await race(seconds) { await task.value }
  }

  private static func race<T>(
    _ seconds: TimeInterval,
    _ wait: @escaping () async throws -> T
  ) async throws -> T? {
    try await withCheckedThrowingContinuation { continuation in
      let outcome = FirstOutcome(continuation)
      let timer = Task {
        try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        outcome.finish(with: .success(nil))
      }
      Task {
        do {
          outcome.finish(with: .success(try await wait()))
        } catch {
          outcome.finish(with: .failure(error))
        }
        timer.cancel()
      }
    }
  }
}

/// Hands a continuation whichever result arrives first, and ignores the rest.
private final class FirstOutcome<T>: @unchecked Sendable {
  private let lock = NSLock()
  private var pending: CheckedContinuation<T, Error>?

  init(_ continuation: CheckedContinuation<T, Error>) {
    pending = continuation
  }

  func finish(with result: Result<T, Error>) {
    lock.lock()
    let continuation = pending
    pending = nil
    lock.unlock()
    continuation?.resume(with: result)
  }
}
