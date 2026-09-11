//
//  SerialTaskCoordinator.swift
//
//
//  Created by Yusuf Tör on 11/09/2026.
//

import Foundation

/// Runs enqueued operations one at a time, in the order they were enqueued.
///
/// The usual way of doing this is to keep the last task in a property and swap
/// it for a new task that waits on the old one:
///
/// ```swift
/// previousTask = Task { [previousTask] in
///   await previousTask?.value
///   ...
/// }
/// ```
///
/// That read and that write aren't a single step, so when callers arrive on
/// different threads two of them can read the same previous task and both
/// release it. That over-releases the task and crashes in `swift_release` when
/// it's torn down. It also loses one of the two new tasks, so the chaining the
/// code is there to provide silently stops happening.
///
/// Handing operations to a single long-lived task through a stream avoids the
/// problem rather than guarding it: there's no task reference to swap. The
/// stream keeps them in the order they were handed over, and ``enqueue(_:)``
/// only hands one over, so no caller ever waits — including callers already
/// running on the concurrency pool.
final class SerialTaskCoordinator {
  typealias Operation = @Sendable () async -> Void

  private let continuation: AsyncStream<Operation>.Continuation

  init() {
    // `AsyncStream` hands over the continuation before its initializer
    // returns, so this is always set by the time it's read.
    // swiftlint:disable:next implicitly_unwrapped_optional
    var continuation: AsyncStream<Operation>.Continuation!
    let operations = AsyncStream<Operation>(bufferingPolicy: .unbounded) {
      continuation = $0
    }
    self.continuation = continuation

    Task {
      for await operation in operations {
        await operation()
      }
    }
  }

  deinit {
    continuation.finish()
  }

  /// Adds `operation` to the end of the queue. It starts only after everything
  /// enqueued before it has finished.
  func enqueue(_ operation: @escaping Operation) {
    continuation.yield(operation)
  }

  /// Waits for everything enqueued so far to finish.
  func drain() async {
    await withCheckedContinuation { continuation in
      enqueue {
        continuation.resume()
      }
    }
  }
}
