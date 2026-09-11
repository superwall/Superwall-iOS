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
/// Doing the swap on a serial queue fixes both. Only the swap runs on the
/// queue — making a task doesn't start it — so a caller never waits on the
/// work itself, only on another caller's swap.
final class SerialTaskCoordinator: @unchecked Sendable {
  private let queue: DispatchQueue
  private var currentTask: Task<Void, Never>?

  /// The task at the end of the queue, if there is one.
  var lastTask: Task<Void, Never>? {
    queue.sync { currentTask }
  }

  /// - Parameter label: Names the queue so it can be told apart from other
  /// coordinators in crash reports and Instruments.
  init(label: String) {
    queue = DispatchQueue(label: "com.superwall.\(label)")
  }

  /// Adds `operation` to the end of the queue. It starts only after everything
  /// enqueued before it has finished.
  func enqueue(_ operation: @escaping @Sendable () async -> Void) {
    queue.sync {
      let previous = currentTask
      currentTask = Task {
        await previous?.value
        await operation()
      }
    }
  }
}
