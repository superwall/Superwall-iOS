//
//  SerialDispatcher.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//

import Foundation

/// Runs synchronous work one item at a time, in the order it was handed
/// over, without ever blocking the caller.
///
/// The first caller to find nothing running runs its work on its own thread,
/// then anything handed over meanwhile, before it returns. A caller that
/// finds work already running, on its own thread (from inside that work) or
/// another, hands its work to the running thread and returns straight away.
/// No lock is held while work runs, so work can call anything, including
/// code that waits on the caller of another `run(_:)`.
final class SerialDispatcher: @unchecked Sendable {
  private let lock = NSLock()
  private var pending: [() -> Void] = []
  private var isDraining = false

  func run(_ work: @escaping () -> Void) {
    let shouldDrain: Bool = withLock {
      pending.append(work)
      if isDraining {
        return false
      }
      isDraining = true
      return true
    }
    guard shouldDrain else {
      return
    }

    while let next = next() {
      next()
    }
  }

  /// Takes the next item, or stops draining if there's none.
  private func next() -> (() -> Void)? {
    withLock {
      if pending.isEmpty {
        isDraining = false
        return nil
      }
      return pending.removeFirst()
    }
  }

  private func withLock<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }
}
