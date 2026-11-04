//
//  SequentialStoreTests.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

private struct Counter {
  var value = 0
  var log: [String] = []
}

private struct Add: Reducer {
  let amount: Int
  func reduce(_ state: Counter) -> Counter {
    var state = state
    state.value += amount
    return state
  }
}

private struct Log: Reducer {
  let entry: String
  func reduce(_ state: Counter) -> Counter {
    var state = state
    state.log.append(entry)
    return state
  }
}

/// The context is just the store, which is all these actions need.
private typealias TestStore = SequentialStore<TestContext, Counter>

private final class TestContext: @unchecked Sendable {
  let store = TestStore(initial: Counter())
}

/// Runs a closure as an action.
private struct Run: StoreAction {
  let name: String
  let body: (TestContext) async -> Void

  init(_ name: String = "run", _ body: @escaping (TestContext) async -> Void) {
    self.name = name
    self.body = body
  }

  func execute(in context: TestContext) async {
    await body(context)
  }
}

/// Runs a closure synchronously as an action.
private struct SyncRun: SyncStoreAction {
  let name: String
  let body: (TestContext) -> Void

  init(_ name: String = "sync", _ body: @escaping (TestContext) -> Void) {
    self.name = name
    self.body = body
  }

  func execute(in context: TestContext) {
    body(context)
  }
}

/// Sets the counter to a value, so a test can read, then write, and see
/// whether anything ran in between.
private struct SetValue: Reducer {
  let value: Int
  func reduce(_ state: Counter) -> Counter {
    var state = state
    state.value = value
    return state
  }
}

/// A mutable value shared with closures that run on other threads.
private final class Box<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: Value

  init(_ value: Value) {
    _value = value
  }

  var value: Value {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _value
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _value = newValue
    }
  }
}

/// Lets a test hold an action at a known point until it says so.
private final class Gate: @unchecked Sendable {
  private let lock = NSLock()
  private var opened = false
  private var waiting: [CheckedContinuation<Void, Never>] = []

  func wait() async {
    await withCheckedContinuation { continuation in
      lock.lock()
      if opened {
        lock.unlock()
        continuation.resume()
        return
      }
      waiting.append(continuation)
      lock.unlock()
    }
  }

  func open() {
    lock.lock()
    opened = true
    let waiting = self.waiting
    self.waiting = []
    lock.unlock()
    waiting.forEach { $0.resume() }
  }
}

@Suite("SequentialStore")
struct SequentialStoreTests {
  @Test("update applies the reducer and state reads it back synchronously")
  func updateAppliesReducer() {
    let context = TestContext()
    context.store.update(Add(amount: 2))
    context.store.update(Add(amount: 3))
    #expect(context.store.state.value == 5)
  }

  @Test("effects run one at a time in dispatch order, even when they suspend")
  func effectsRunInOrderWithoutInterleaving() async {
    let context = TestContext()
    let store = context.store

    for index in 0..<20 {
      store.effect(
        Run { context in
          context.store.update(Log(entry: "start \(index)"))
          // Suspends mid-action. A plain Swift actor would let the next
          // action start here.
          await Task.yield()
          try? await Task.sleep(nanoseconds: UInt64.random(in: 0...200_000))
          context.store.update(Log(entry: "end \(index)"))
        },
        in: context
      )
    }
    await store.flush()

    let expected = (0..<20).flatMap { ["start \($0)", "end \($0)"] }
    #expect(store.state.log == expected)
  }

  @Test("effect returns before the action runs")
  func effectDoesNotWait() async {
    let context = TestContext()
    let gate = Gate()
    context.store.effect(
      Run { context in
        await gate.wait()
        context.store.update(Add(amount: 1))
      },
      in: context
    )
    #expect(context.store.state.value == 0)
    gate.open()
    await context.store.flush()
    #expect(context.store.state.value == 1)
  }

  @Test("immediate from outside waits behind already queued actions")
  func immediateWaitsItsTurn() async {
    let context = TestContext()
    let gate = Gate()
    context.store.effect(
      Run { context in
        await gate.wait()
        context.store.update(Log(entry: "first"))
      },
      in: context
    )

    let immediate = Task {
      await context.store.immediate(
        Run { $0.store.update(Log(entry: "second")) },
        in: context
      )
      return context.store.state.log
    }
    gate.open()

    #expect(await immediate.value == ["first", "second"])
  }

  @Test("immediate from inside an action runs inline instead of deadlocking")
  func immediateIsReentrant() async {
    let context = TestContext()
    await context.store.immediate(
      Run { context in
        context.store.update(Log(entry: "outer start"))
        await context.store.immediate(
          Run { $0.store.update(Log(entry: "inner")) },
          in: context
        )
        context.store.update(Log(entry: "outer end"))
      },
      in: context
    )
    #expect(context.store.state.log == ["outer start", "inner", "outer end"])
  }

  @Test("effect from inside an action runs after the current action finishes")
  func nestedEffectIsQueued() async {
    let context = TestContext()
    await context.store.immediate(
      Run { context in
        context.store.effect(
          Run { $0.store.update(Log(entry: "follow-up")) },
          in: context
        )
        context.store.update(Log(entry: "outer"))
      },
      in: context
    )
    await context.store.flush()
    #expect(context.store.state.log == ["outer", "follow-up"])
  }

  @Test("flush from inside an action returns instead of deadlocking")
  func flushIsReentrant() async {
    let context = TestContext()
    await context.store.immediate(
      Run { context in
        await context.store.flush()
        context.store.update(Add(amount: 1))
      },
      in: context
    )
    #expect(context.store.state.value == 1)
  }

  @Test("a task started by a finished action is treated as outside the store")
  func strayTaskAfterActionIsNotInline() async {
    let context = TestContext()
    let gate = Gate()
    var stray: Task<[String], Never>?

    await context.store.immediate(
      Run { context in
        stray = Task {
          await gate.wait()
          // The action that started this task has finished by now, so this
          // must queue behind the blocker rather than run inline.
          await context.store.immediate(
            Run { $0.store.update(Log(entry: "stray")) },
            in: context
          )
          return context.store.state.log
        }
      },
      in: context
    )

    let blocker = Gate()
    context.store.effect(
      Run { context in
        await blocker.wait()
        context.store.update(Log(entry: "blocker"))
      },
      in: context
    )
    gate.open()
    // Give the stray task a chance to (wrongly) run inline before the blocker.
    try? await Task.sleep(nanoseconds: 20_000_000)
    blocker.open()

    #expect(await stray?.value == ["blocker", "stray"])
  }

  @Test("A task started inside an action is outside it, even while the action runs")
  func taskStartedInsideActionIsQueued() async {
    let context = TestContext()
    let spawned = Box<Task<Void, Never>?>(nil)

    await context.store.immediate(
      Run { context in
        spawned.value = Task {
          // Would run inline, alongside this action, if the task inherited
          // the action's identity.
          await context.store.immediate(
            Run { $0.store.update(Log(entry: "spawned")) },
            in: context
          )
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        context.store.update(Log(entry: "action end"))
      },
      in: context
    )
    await spawned.value?.value

    #expect(context.store.state.log == ["action end", "spawned"])
  }

  @Test("waitUntil returns at once when the state already matches")
  func waitUntilCurrentState() async throws {
    let context = TestContext()
    context.store.update(Add(amount: 3))
    let state = try await context.store.waitUntil { $0.value == 3 }
    #expect(state.value == 3)
  }

  @Test("waitUntil returns the first matching state")
  func waitUntilFutureState() async throws {
    let context = TestContext()
    let registered = Gate()
    let waiter = Task {
      try await context.store.waitUntil {
        // First called while registering, with the current state.
        registered.open()
        return $0.value >= 2
      }
    }
    await registered.wait()
    context.store.update(Add(amount: 1))
    context.store.update(Add(amount: 1))
    context.store.update(Add(amount: 1))
    #expect(try await waiter.value.value == 2)
  }

  @Test("waitUntil throws when its task is cancelled")
  func waitUntilCancellation() async throws {
    let context = TestContext()
    let waiter = Task {
      try await context.store.waitUntil { $0.value == 100 }
    }
    try await Task.sleep(nanoseconds: 10_000_000)
    waiter.cancel()
    await #expect(throws: CancellationError.self) {
      try await waiter.value
    }
  }

  @Test("immediateUntil returns once the action has moved the state")
  func immediateUntilSeesTheChange() async throws {
    let context = TestContext()
    let started = Gate()
    let gate = Gate()
    let result = Task {
      try await context.store.immediateUntil(
        Run { context in
          context.store.update(Add(amount: 1))
          started.open()
          await gate.wait()
          context.store.update(Add(amount: 1))
        },
        in: context,
        until: { $0.value == 2 }
      )
    }
    await started.wait()
    #expect(context.store.state.value == 1)
    gate.open()
    #expect(try await result.value.value == 2)
  }

  @Test("immediateUntil still queues its action when the state already matches")
  func immediateUntilAlreadyMatching() async throws {
    let context = TestContext()
    let state = try await context.store.immediateUntil(
      Run { $0.store.update(Log(entry: "ran")) },
      in: context,
      until: { _ in true }
    )
    #expect(state.log.isEmpty)
    await context.store.flush()
    #expect(context.store.state.log == ["ran"])
  }

  @Test("update interceptors wrap updates and can suppress them")
  func updateInterceptors() {
    let context = TestContext()
    var seen: [String] = []
    context.store.onUpdate { reducer, next in
      seen.append("outer before")
      next()
      seen.append("outer after")
    }
    context.store.onUpdate { reducer, next in
      // Added last, so it runs first.
      if (reducer as? Add)?.amount == 99 {
        seen.append("suppressed")
        return
      }
      seen.append("inner")
      next()
    }

    context.store.update(Add(amount: 1))
    context.store.update(Add(amount: 99))

    #expect(context.store.state.value == 1)
    #expect(seen == ["inner", "outer before", "outer after", "suppressed"])
  }

  @Test("action interceptors run synchronously on dispatch and can suppress the action")
  func actionInterceptors() async {
    let context = TestContext()
    var dispatched: [String] = []
    context.store.onAction { action, next in
      guard let run = action as? Run else {
        return next()
      }
      dispatched.append(run.name)
      if run.name == "blocked" {
        return
      }
      next()
    }

    context.store.effect(Run("allowed") { $0.store.update(Add(amount: 1)) }, in: context)
    // Recorded before the action had a chance to run.
    #expect(dispatched == ["allowed"])
    context.store.effect(Run("blocked") { $0.store.update(Add(amount: 100)) }, in: context)
    await context.store.immediate(Run("blocked") { $0.store.update(Add(amount: 100)) }, in: context)
    await context.store.flush()

    #expect(dispatched == ["allowed", "blocked", "blocked"])
    #expect(context.store.state.value == 1)
  }

  @Test("execution interceptors wrap the whole action, including inline nested ones")
  func executionInterceptors() async {
    let context = TestContext()
    context.store.onActionExecution { action, next in
      let name = (action as? Run)?.name ?? "?"
      context.store.update(Log(entry: "begin \(name)"))
      await next()
      context.store.update(Log(entry: "end \(name)"))
    }

    await context.store.immediate(
      Run("outer") { context in
        await context.store.immediate(Run("inner") { _ in }, in: context)
      },
      in: context
    )

    #expect(context.store.state.log == ["begin outer", "begin inner", "end inner", "end outer"])
  }

  @Test("concurrent updates from many threads aren't lost")
  func concurrentUpdates() async {
    let context = TestContext()
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<1000 {
        group.addTask {
          context.store.update(Add(amount: 1))
        }
      }
    }
    #expect(context.store.state.value == 1000)
  }

  @Test("effects dispatched from one thread keep their order across many threads")
  func effectsFromManyThreads() async {
    let context = TestContext()
    await withTaskGroup(of: Void.self) { group in
      for thread in 0..<10 {
        group.addTask {
          for index in 0..<50 {
            context.store.effect(
              Run { $0.store.update(Log(entry: "\(thread)-\(index)")) },
              in: context
            )
          }
        }
      }
    }
    await context.store.flush()

    let log = context.store.state.log
    #expect(log.count == 500)
    for thread in 0..<10 {
      let entries = log.filter { $0.hasPrefix("\(thread)-") }
      #expect(entries == (0..<50).map { "\(thread)-\($0)" })
    }
  }

  // MARK: - dispatch

  @Test("dispatch runs the action before returning")
  func dispatchIsSynchronous() {
    let context = TestContext()
    context.store.dispatch(SyncRun { $0.store.update(Add(amount: 1)) }, in: context)
    #expect(context.store.state.value == 1)
  }

  @Test("dispatch from inside a dispatched action runs after it, before the outer dispatch returns")
  func nestedDispatchIsDeferred() {
    let context = TestContext()
    context.store.dispatch(
      SyncRun { context in
        context.store.update(Log(entry: "outer start"))
        context.store.dispatch(
          SyncRun { $0.store.update(Log(entry: "nested")) },
          in: context
        )
        context.store.update(Log(entry: "outer end"))
      },
      in: context
    )
    #expect(context.store.state.log == ["outer start", "outer end", "nested"])
  }

  @Test("Dispatches from many threads never overlap")
  func dispatchesAreSerialized() async {
    let context = TestContext()
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<500 {
        group.addTask {
          context.store.dispatch(
            SyncRun { context in
              // A read, then a write. Another action in between would lose
              // an increment.
              let value = context.store.state.value
              context.store.update(SetValue(value: value + 1))
            },
            in: context
          )
        }
      }
    }
    #expect(context.store.state.value == 500)
  }

  @Test("dispatch while another thread is running actions waits for its own action")
  func contendedDispatchWaits() {
    let context = TestContext()
    let started = DispatchSemaphore(value: 0)
    let proceed = DispatchSemaphore(value: 0)
    let secondReturned = DispatchSemaphore(value: 0)
    let firstFinished = DispatchSemaphore(value: 0)
    let box = Box<[String]>([])

    Thread {
      context.store.dispatch(
        SyncRun { context in
          started.signal()
          _ = proceed.wait(timeout: .now() + 5)
          context.store.update(Log(entry: "first"))
        },
        in: context
      )
      firstFinished.signal()
    }
    .start()
    started.wait()

    Thread {
      context.store.dispatch(SyncRun { $0.store.update(Log(entry: "second")) }, in: context)
      box.value = context.store.state.log
      secondReturned.signal()
    }
    .start()

    // Still waiting behind the first action.
    #expect(secondReturned.wait(timeout: .now() + 0.1) == .timedOut)
    proceed.signal()
    #expect(secondReturned.wait(timeout: .now() + 5) == .success)
    firstFinished.wait()
    // Its read straight after dispatch saw its own action.
    #expect(box.value == ["first", "second"])
  }

  @Test("dispatch while the running action calls out returns without waiting")
  func dispatchDuringCalloutDoesNotWait() {
    let context = TestContext()
    let started = DispatchSemaphore(value: 0)
    let proceed = DispatchSemaphore(value: 0)
    let finished = DispatchSemaphore(value: 0)
    let box = Box(false)

    Thread {
      context.store.dispatch(
        SyncRun { context in
          context.store.callingOut {
            started.signal()
            // Stands in for a call that waits on something the other
            // dispatcher holds. If that dispatcher waited, both would be stuck.
            box.value = proceed.wait(timeout: .now() + 5) == .success
          }
          context.store.update(Log(entry: "first"))
        },
        in: context
      )
      finished.signal()
    }
    .start()

    started.wait()
    context.store.dispatch(SyncRun { $0.store.update(Log(entry: "second")) }, in: context)
    #expect(context.store.state.log.isEmpty)
    proceed.signal()
    finished.wait()

    #expect(box.value)
    #expect(context.store.state.log == ["first", "second"])
  }

  @Test("A caller already waiting stops waiting when the running action calls out")
  func calloutReleasesWaitingCallers() {
    let context = TestContext()
    let started = DispatchSemaphore(value: 0)
    let calloutStarted = DispatchSemaphore(value: 0)
    let proceed = DispatchSemaphore(value: 0)
    let secondReturned = DispatchSemaphore(value: 0)
    let finished = DispatchSemaphore(value: 0)

    Thread {
      context.store.dispatch(
        SyncRun { context in
          started.signal()
          // Give the second caller time to start waiting.
          Thread.sleep(forTimeInterval: 0.05)
          context.store.callingOut {
            calloutStarted.signal()
            _ = proceed.wait(timeout: .now() + 5)
          }
          context.store.update(Log(entry: "first"))
        },
        in: context
      )
      finished.signal()
    }
    .start()
    started.wait()

    Thread {
      context.store.dispatch(SyncRun { $0.store.update(Log(entry: "second")) }, in: context)
      secondReturned.signal()
    }
    .start()

    calloutStarted.wait()
    #expect(secondReturned.wait(timeout: .now() + 2) == .success)
    proceed.signal()
    finished.wait()
    #expect(context.store.state.log == ["first", "second"])
  }

  @Test("Action interceptors apply to dispatch")
  func dispatchRunsActionInterceptors() {
    let context = TestContext()
    var seen: [String] = []
    context.store.onAction { action, next in
      seen.append((action as? SyncRun)?.name ?? "?")
      if (action as? SyncRun)?.name == "blocked" {
        return
      }
      next()
    }
    context.store.dispatch(SyncRun("allowed") { $0.store.update(Add(amount: 1)) }, in: context)
    context.store.dispatch(SyncRun("blocked") { $0.store.update(Add(amount: 100)) }, in: context)
    #expect(seen == ["allowed", "blocked"])
    #expect(context.store.state.value == 1)
  }
}
