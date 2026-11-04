//
//  SequentialStore.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//

import Foundation

/// Holds a piece of state and runs the actions that change it one at a time,
/// in the order they were dispatched.
///
/// This is the counterpart of the Android SDK's `SequentialActor`. A Swift
/// `actor` alone isn't enough here: an actor lets another call in at every
/// `await`, so an action that waits on the network would interleave with the
/// next one. This store runs each action to completion before it starts the
/// next one, however many times the action suspends.
///
/// - ``state`` can be read synchronously from any thread.
/// - ``update(_:)`` applies a ``Reducer`` atomically.
/// - ``effect(_:in:)`` queues an action and returns straight away. The action
///   is queued before the call returns, so effects dispatched from one thread
///   run in the order they were dispatched.
/// - ``immediate(_:in:)`` queues an action and waits for it to finish. Called
///   from inside an action on the same store, it runs the action inline, since
///   waiting for the queue from inside the queue would never finish.
/// - ``dispatch(_:in:)`` runs a ``SyncStoreAction`` one at a time with other
///   dispatches and returns once it has run, for state whose changes never
///   wait and whose callers read it back synchronously.
/// - ``flush()`` waits for everything queued so far, which makes tests
///   deterministic without sleeping.
///
/// Only the task running an action counts as inside it. Any other task,
/// including one the action starts or a child task it awaits, is outside it:
/// its ``immediate(_:in:)`` waits for the action to finish. So an action must
/// not await a task that calls ``immediate(_:in:)`` or ``flush()`` on the
/// same store. Use ``effect(_:in:)`` for follow-up work instead.
///
/// ## Interceptors
///
/// Interceptors are installed once, while setting up the store, and wrap
/// every update or action. Call `next` to continue, or skip it to suppress:
///
/// ```swift
/// store.onUpdate { reducer, next in
///   next()
///   persist(store.state)
/// }
/// ```
final class SequentialStore<Context, State>: @unchecked Sendable {
  /// Wraps a state update. `reducer` is the reducer being applied.
  typealias UpdateInterceptor = (_ reducer: Any, _ next: () -> Void) -> Void
  /// Wraps the dispatch of an action. Runs synchronously on the caller's
  /// thread before the action is queued, so it can mark work as pending.
  typealias ActionInterceptor = (_ action: Any, _ next: () -> Void) -> Void
  /// Wraps the execution of an action on the queue. `next` returns when the
  /// action has finished.
  typealias ExecutionInterceptor = (_ action: Any, _ next: () async -> Void) async -> Void

  private enum WaitRegistration {
    case cancelled
    case matched(State)
    case waiting
  }

  private struct Waiter {
    let id: UInt64
    let predicate: (State) -> Bool
    let continuation: CheckedContinuation<State, Error>
  }

  private let lock = NSLock()
  private var _state: State
  private var waiters: [Waiter] = []
  private var nextWaiterId: UInt64 = 0
  /// The task running the current action, while one runs. Only compared,
  /// never used to reach the task, and cleared before that task finishes.
  private var activeJobTask: UnsafeCurrentTask?

  private var updateInterceptors: [UpdateInterceptor] = []
  private var actionInterceptors: [ActionInterceptor] = []
  private var executionInterceptors: [ExecutionInterceptor] = []

  private let coordinator = SerialTaskCoordinator()

  /// Runs ``dispatch(_:in:)``'s actions one at a time without blocking.
  private let dispatcher = SerialDispatcher()

  /// The current state.
  var state: State {
    withLock { _state }
  }

  init(initial: State) {
    _state = initial
  }

  deinit {
    // Queued jobs keep the store alive, so nothing can be waiting on the
    // queue by now. Anything still waiting on a state change never will see it.
    for waiter in waiters {
      waiter.continuation.resume(throwing: CancellationError())
    }
  }

  // MARK: - Interceptors

  /// Adds an interceptor around every state update. The most recently added
  /// interceptor runs first.
  func onUpdate(_ interceptor: @escaping UpdateInterceptor) {
    withLock { updateInterceptors.insert(interceptor, at: 0) }
  }

  /// Adds an interceptor around the dispatch of every action. Interceptors run
  /// in the order they were added.
  func onAction(_ interceptor: @escaping ActionInterceptor) {
    withLock { actionInterceptors.append(interceptor) }
  }

  /// Adds an interceptor around the execution of every action. Interceptors
  /// run in the order they were added.
  func onActionExecution(_ interceptor: @escaping ExecutionInterceptor) {
    withLock { executionInterceptors.append(interceptor) }
  }

  // MARK: - State

  /// Applies `reducer` to the state atomically, through the update interceptors.
  func update<R: Reducer>(_ reducer: R) where R.State == State {
    let interceptors = withLock { updateInterceptors }

    var chain: () -> Void = { [self] in
      apply(reducer)
    }
    for interceptor in interceptors.reversed() {
      let next = chain
      chain = { interceptor(reducer, next) }
    }
    chain()
  }

  private func apply<R: Reducer>(_ reducer: R) where R.State == State {
    let (newState, satisfied) = withLock {
      _state = reducer.reduce(_state)
      let newState = _state
      var satisfied: [Waiter] = []
      waiters.removeAll { waiter in
        guard waiter.predicate(newState) else {
          return false
        }
        satisfied.append(waiter)
        return true
      }
      return (newState, satisfied)
    }

    for waiter in satisfied {
      waiter.continuation.resume(returning: newState)
    }
  }

  /// Returns the first state that matches `predicate`, which may be the
  /// current one.
  ///
  /// - Throws: `CancellationError` if the calling task is cancelled first.
  @discardableResult
  func waitUntil(_ predicate: @escaping (State) -> Bool) async throws -> State {
    try await waitUntil(predicate) {}
  }

  /// Registers the wait before running `afterRegistering`, so a state change
  /// that `afterRegistering` causes can't be missed.
  private func waitUntil(
    _ predicate: @escaping (State) -> Bool,
    afterRegistering: () -> Void
  ) async throws -> State {
    let id = withLock {
      nextWaiterId += 1
      return nextWaiterId
    }

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let registration: WaitRegistration = withLock {
          if Task.isCancelled {
            return .cancelled
          }
          if predicate(_state) {
            return .matched(_state)
          }
          waiters.append(Waiter(id: id, predicate: predicate, continuation: continuation))
          return .waiting
        }
        switch registration {
        case .cancelled:
          continuation.resume(throwing: CancellationError())
        case .matched(let state):
          continuation.resume(returning: state)
        case .waiting:
          afterRegistering()
        }
      }
    } onCancel: {
      let waiter: Waiter? = withLock {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else {
          return nil
        }
        return waiters.remove(at: index)
      }
      waiter?.continuation.resume(throwing: CancellationError())
    }
  }

  // MARK: - Dispatch

  /// Queues `action` and returns without waiting for it.
  func effect<A: StoreAction>(
    _ action: A,
    in context: Context
  ) where A.Context == Context {
    runActionInterceptors(action) { [self] in
      enqueue { [self] in
        await execute(action, in: context)
      }
    }
  }

  /// Runs `action` and returns when it has finished.
  ///
  /// From outside the store, the action waits its turn behind everything
  /// already queued. From inside one of this store's actions, it runs inline.
  func immediate<A: StoreAction>(
    _ action: A,
    in context: Context
  ) async where A.Context == Context {
    var shouldExecute = false
    runActionInterceptors(action) {
      shouldExecute = true
    }
    guard shouldExecute else {
      return
    }

    if isRunningOwnJob {
      await execute(action, in: context)
      return
    }

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      enqueue { [self] in
        await execute(action, in: context)
        continuation.resume()
      }
    }
  }

  /// Queues `action`, then returns the first state that matches `until`.
  ///
  /// - Throws: `CancellationError` if the calling task is cancelled first.
  @discardableResult
  func immediateUntil<A: StoreAction>(
    _ action: A,
    in context: Context,
    until: @escaping (State) -> Bool
  ) async throws -> State where A.Context == Context {
    try await waitUntil(until) {
      effect(action, in: context)
    }
  }

  /// Runs a ``SyncStoreAction``, one at a time with other dispatched actions,
  /// in dispatch order, and normally returns once it has run, so a read on
  /// this thread straight after sees it.
  ///
  /// Use this instead of ``effect(_:in:)`` for actions that never wait:
  /// - When no other thread is running dispatched actions, `action` runs on
  ///   the calling thread, followed by any actions dispatched meanwhile.
  /// - From inside a dispatched action, it runs once that action finishes,
  ///   before the outer dispatch returns.
  /// - While another thread is running dispatched actions, this waits for
  ///   that thread to run it. Unless that thread is inside ``callingOut(_:)``:
  ///   then this returns straight away and the action runs later, since the
  ///   running action may be waiting on something the caller holds.
  ///
  /// Execution interceptors don't apply. See ``SerialDispatcher``.
  func dispatch<A: SyncStoreAction>(
    _ action: A,
    in context: Context
  ) where A.Context == Context {
    let run = { [self] in
      runActionInterceptors(action) {
        action.execute(in: context)
      }
    }

    dispatcher.run(run)
  }

  /// Runs `body` from inside a dispatched action, letting ``dispatch(_:in:)``
  /// callers on other threads return without waiting while it runs. Wrap
  /// calls that can block on something such a caller might hold.
  func callingOut<T>(_ body: () -> T) -> T {
    dispatcher.callingOut(body)
  }

  /// Returns once everything queued before this call has finished.
  ///
  /// From inside one of this store's actions it returns straight away, since
  /// the queue can't drain while that action is still running.
  func flush() async {
    if isRunningOwnJob {
      return
    }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      enqueue {
        continuation.resume()
      }
    }
  }

  // MARK: - Private

  /// Whether the current task is the one running this store's action.
  ///
  /// Tasks are compared rather than tracked with a task-local value, which
  /// every task started inside the action would inherit. Those would then
  /// run their own actions inline, alongside the one still running.
  private var isRunningOwnJob: Bool {
    withUnsafeCurrentTask { current in
      guard let current = current else {
        return false
      }
      return withLock { activeJobTask == current }
    }
  }

  /// Runs `body` while holding the lock. Synchronous, so it can't hold the
  /// lock across a suspension point.
  private func withLock<T>(_ body: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try body()
  }

  private func enqueue(_ work: @escaping () async -> Void) {
    coordinator.enqueue { [self] in
      beginJob()
      await work()
      endJob()
    }
  }

  private func beginJob() {
    withUnsafeCurrentTask { current in
      withLock { activeJobTask = current }
    }
  }

  private func endJob() {
    withLock { activeJobTask = nil }
  }

  private func runActionInterceptors(
    _ action: Any,
    terminal: @escaping () -> Void
  ) {
    let interceptors = withLock { actionInterceptors }

    var chain = terminal
    for interceptor in interceptors.reversed() {
      let next = chain
      chain = { interceptor(action, next) }
    }
    chain()
  }

  private func execute<A: StoreAction>(
    _ action: A,
    in context: Context
  ) async where A.Context == Context {
    let interceptors = withLock { executionInterceptors }

    var chain: () async -> Void = {
      await action.execute(in: context)
    }
    for interceptor in interceptors.reversed() {
      let next = chain
      chain = { await interceptor(action, next) }
    }
    await chain()
  }
}
