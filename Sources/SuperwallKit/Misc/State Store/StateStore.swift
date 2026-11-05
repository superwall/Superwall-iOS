//
//  StateStore.swift
//  SuperwallKit
//
//  Created by Superwall on 04/11/2026.
//

import Foundation

/// Holds a piece of state behind one lock, and changes it only through
/// ``Reducer``s and ``StoreAction``s.
///
/// - ``state`` can be read from any thread, and reflects every change that
///   has returned, on any thread.
/// - ``update(_:)`` applies a reducer atomically, then tells the observers.
/// - ``dispatch(_:in:)`` runs an action with the store locked, so actions on
///   different threads never interleave, and a read on the dispatching
///   thread straight after sees what the action did.
/// - ``deferUntilUnlocked(_:)`` runs work from inside an action or observer
///   once the store is unlocked, for work that may wait on other objects.
///
/// Everything that runs with the store locked (actions, reducers and
/// observers) must not wait on another thread, which may be waiting for this
/// lock while holding what it would wait for.
///
/// The lock is recursive, so an action or observer can read the state,
/// update it, or dispatch another action without deadlocking. A nested
/// dispatch runs straight away, inside the outer action. An update made by
/// an observer is applied straight away too, but observers hear about it
/// only once all of them have heard about the update in progress.
final class StateStore<Context, State>: @unchecked Sendable {
  /// Told about every update, with the state before and after it.
  typealias Observer = (_ before: State, _ after: State) -> Void

  private let lock = NSRecursiveLock()
  private var _state: State
  private var observers: [Observer] = []
  /// How many updates and dispatches the thread holding the lock is inside.
  private var depth = 0
  /// Work deferred until the outermost update or dispatch finishes.
  private var deferredWork: [() -> Void] = []
  /// Updates the observers haven't heard about yet, oldest first.
  private var pendingNotifications: [(before: State, after: State)] = []
  /// Whether the observers are being told about an update.
  private var isNotifying = false

  /// The current state.
  var state: State {
    lock.lock()
    defer { lock.unlock() }
    return _state
  }

  init(initial: State) {
    _state = initial
  }

  /// Adds an observer, told about every later update in the order the
  /// updates are applied. Observers run with the store locked, one update at
  /// a time, so they can save or publish the state without a newer update
  /// overtaking an older one.
  func observe(_ observer: @escaping Observer) {
    locked { observers.append(observer) }
  }

  /// Applies `reducer` to the state atomically, then tells the observers.
  ///
  /// Called from an observer, it returns once the state has changed, and the
  /// observers are told about it after the update they're being told about.
  /// So each observer hears about every update in the order they were
  /// applied, and the last `after` it hears is the current state.
  func update<R: Reducer>(_ reducer: R) where R.State == State {
    locked {
      let before = _state
      _state = reducer.reduce(before)
      pendingNotifications.append((before, _state))
      guard !isNotifying else {
        return
      }
      isNotifying = true
      while !pendingNotifications.isEmpty {
        let notification = pendingNotifications.removeFirst()
        for observer in observers {
          observer(notification.before, notification.after)
        }
      }
      isNotifying = false
    }
  }

  /// Runs `action` with the store locked, then any work deferred with
  /// ``deferUntilUnlocked(_:)``, before returning.
  ///
  /// Dispatches on other threads wait for the lock, so actions never
  /// interleave. Dispatched from inside an action, `action` runs straight
  /// away, inside the outer one.
  func dispatch<A: StoreAction>(
    _ action: A,
    in context: Context
  ) where A.Context == Context {
    locked {
      action.execute(in: context)
    }
  }

  /// Runs `work` once this thread has finished the update or dispatch it's
  /// in and the store is unlocked, before that update or dispatch returns.
  /// Called outside one, `work` runs before this returns, once any update or
  /// dispatch running on another thread has released the lock.
  ///
  /// Work deferred within one outermost update or dispatch runs in the order
  /// it was deferred. It may wait on other objects, and update the store or
  /// dispatch actions. An update or dispatch made from deferred work is
  /// outermost too, so the work it defers runs before it returns, ahead of
  /// work the outer one deferred after the running item. That keeps the
  /// promise that a dispatch has finished everything it deferred when it
  /// returns, wherever it's called from.
  func deferUntilUnlocked(_ work: @escaping () -> Void) {
    lock.lock()
    // While this thread holds the lock, no other thread can be inside an
    // update or dispatch, so a depth above zero is this thread's.
    guard depth > 0 else {
      lock.unlock()
      work()
      return
    }
    deferredWork.append(work)
    lock.unlock()
  }

  /// Runs `body` with the store locked, then, if it was the outermost
  /// update or dispatch, the work deferred meanwhile.
  private func locked(_ body: () -> Void) {
    lock.lock()
    depth += 1
    body()
    depth -= 1
    var work: [() -> Void] = []
    if depth == 0 {
      work = deferredWork
      deferredWork = []
    }
    lock.unlock()

    for item in work {
      item()
    }
  }
}
