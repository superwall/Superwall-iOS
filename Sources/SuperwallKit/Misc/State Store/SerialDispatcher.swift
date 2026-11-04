//
//  SerialDispatcher.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//

import Foundation

/// Runs synchronous work one item at a time, in the order it was handed
/// over, and normally returns only once the caller's own work has run.
///
/// - With nothing running, the caller runs its work on its own thread, then
///   anything handed over meanwhile, and returns.
/// - From inside running work (on the thread running it), the new work runs
///   once the current item finishes, before the outer `run(_:)` returns.
/// - While another thread is running work, the caller waits for that thread
///   to run its item too, so that a read straight after `run(_:)` sees it.
///
/// Waiting is only safe while the running work can't block on anything the
/// waiter might hold. Work that calls out to code that can, wraps that in
/// ``callingOut(_:)``: while it runs, callers hand their work over and
/// return straight away, and callers already waiting stop waiting.
final class SerialDispatcher: @unchecked Sendable {
  private struct Item {
    let id: UInt64
    let work: () -> Void
  }

  private let condition = NSCondition()
  private var pending: [Item] = []
  private var lastId: UInt64 = 0
  /// Items run in id order, so every item up to this one has finished.
  private var finishedThrough: UInt64 = 0
  /// The thread running items, if any.
  private var drainer: pthread_t?
  /// How many ``callingOut(_:)`` sections the running item is in.
  private var calloutDepth = 0

  func run(_ work: @escaping () -> Void) {
    condition.lock()
    lastId += 1
    let id = lastId
    pending.append(Item(id: id, work: work))

    if let drainer = drainer {
      if pthread_equal(drainer, pthread_self()) != 0 {
        // From inside running work: runs once it finishes.
        condition.unlock()
        return
      }
      // The drainer runs every pending item before it stops, ours included.
      while finishedThrough < id && calloutDepth == 0 {
        condition.wait()
      }
      condition.unlock()
      return
    }

    drainer = pthread_self()
    condition.unlock()
    drain()
  }

  /// Runs `body`, from inside running work, letting callers on other threads
  /// return without waiting for their work while it runs.
  ///
  /// Use it around calls that can block on something a caller of
  /// ``run(_:)`` might hold, such as another object's `queue.sync`.
  func callingOut<T>(_ body: () -> T) -> T {
    condition.lock()
    calloutDepth += 1
    condition.broadcast()
    condition.unlock()
    defer {
      condition.lock()
      calloutDepth -= 1
      condition.unlock()
    }
    return body()
  }

  private func drain() {
    while true {
      condition.lock()
      if pending.isEmpty {
        drainer = nil
        condition.unlock()
        return
      }
      let item = pending.removeFirst()
      condition.unlock()

      item.work()

      condition.lock()
      finishedThrough = item.id
      condition.broadcast()
      condition.unlock()
    }
  }
}
