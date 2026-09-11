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
/// Holding the swap behind a lock fixes both.
final class SerialTaskCoordinator: @unchecked Sendable {
  private let lock = NSLock()
  private var currentTask: Task<Void, Never>?

  /// The task at the end of the queue, if there is one.
  var lastTask: Task<Void, Never>? {
    lock.lock()
    defer { lock.unlock() }
    return currentTask
  }

  /// Adds `operation` to the end of the queue. It starts only after everything
  /// enqueued before it has finished.
  func enqueue(_ operation: @escaping @Sendable () async -> Void) {
    lock.lock()
    defer { lock.unlock() }

    let previous = currentTask
    currentTask = Task {
      await previous?.value
      await operation()
    }
  }
}
