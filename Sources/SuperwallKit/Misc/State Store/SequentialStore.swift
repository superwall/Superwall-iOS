//
//  SequentialStore.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//
// swiftlint:disable file_length

import Foundation

/// A pure state transform: no side effects and no dispatch.
///
/// Reducers describe how state changes. Storage, network and tracking
/// belong in a ``StoreAction``.
protocol Reducer {
  associatedtype State
  func reduce(_ state: State) -> State
}

/// Async work that runs on a ``SequentialStore``'s queue.
///
/// The context supplies every dependency the action needs, so tests can run
/// an action against a context built from mocks. Actions change state only
/// by passing a ``Reducer`` to ``SequentialStore/update(_:)``.
protocol StoreAction {
  associatedtype Context
  func execute(in context: Context) async
}

/// Identifies the store job that the current task is running, so a store can
/// tell a call made from inside one of its own actions from one made outside.
private struct StoreJob: Hashable {
  let store: ObjectIdentifier
  let job: UInt64
}

private enum StoreExecution {
  @TaskLocal static var current: StoreJob?
}

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
/// - ``flush()`` waits for everything queued so far, which makes tests
///   deterministic without sleeping.
///
/// An unstructured `Task` started inside an action shares that action's
/// identity until the action finishes. Use ``effect(_:in:)`` for follow-up
/// work instead of starting a `Task` that calls back into the store.
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
  private var nextJobId: UInt64 = 0
  private var activeJob: UInt64?

  private var updateInterceptors: [UpdateInterceptor] = []
  private var actionInterceptors: [ActionInterceptor] = []
  private var executionInterceptors: [ExecutionInterceptor] = []

  private let coordinator = SerialTaskCoordinator()

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
    try await waitUntil(predicate, afterRegistering: {})
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

  /// Whether the current task is running this store's active job.
  private var isRunningOwnJob: Bool {
    guard let current = StoreExecution.current else {
      return false
    }
    guard current.store == ObjectIdentifier(self) else {
      return false
    }
    return withLock { activeJob == current.job }
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
      let job = beginJob()
      await StoreExecution.$current.withValue(job) {
        await work()
      }
      endJob()
    }
  }

  private func beginJob() -> StoreJob {
    withLock {
      nextJobId += 1
      activeJob = nextJobId
      return StoreJob(store: ObjectIdentifier(self), job: nextJobId)
    }
  }

  private func endJob() {
    withLock { activeJob = nil }
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
