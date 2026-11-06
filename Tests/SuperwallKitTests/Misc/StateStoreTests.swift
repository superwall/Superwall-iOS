//
//  StateStoreTests.swift
//  SuperwallKit
//
//  Created by Superwall on 04/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

private struct Counter: Equatable {
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

private struct SetValue: Reducer {
  let value: Int
  func reduce(_ state: Counter) -> Counter {
    var state = state
    state.value = value
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

private typealias TestStore = StateStore<TestContext, Counter>

private final class TestContext: @unchecked Sendable {
  let store = TestStore(initial: Counter())
}

/// Runs a closure as an action.
private struct Run: StoreAction {
  let body: (TestContext) -> Void

  init(_ body: @escaping (TestContext) -> Void) {
    self.body = body
  }

  func execute(in context: TestContext) {
    body(context)
  }
}

/// Adds to the counter and returns the value it saw before, in one locked step.
private struct AddReturningPrevious: StoreAction {
  let amount: Int

  func execute(in context: TestContext) -> Int {
    let previous = context.store.state.value
    context.store.update(Add(amount: amount))
    return previous
  }
}

/// A value shared with other threads.
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

  func mutate(_ body: (inout Value) -> Void) {
    lock.lock()
    defer { lock.unlock() }
    body(&_value)
  }
}

/// Starts `body` on a new thread.
private func onThread(_ body: @escaping () -> Void) {
  Thread(block: body).start()
}

@Suite("StateStore")
struct StateStoreTests {
  // MARK: - update

  @Test("update applies the reducer, and the state reads it back")
  func updateAppliesReducer() {
    let store = TestStore(initial: Counter())
    store.update(Add(amount: 2))
    store.update(Add(amount: 3))
    #expect(store.state.value == 5)
  }

  @Test("read returns what the body reads from the current state")
  func read() {
    let context = TestContext()
    context.store.update(Add(amount: 3))
    context.store.update(Log(entry: "a"))
    #expect(context.store.read { $0.value } == 3)
    #expect(context.store.read { $0.log.first } == "a")
  }

  @Test("An update on another thread waits for a read in progress")
  func updateWaitsForRead() {
    let context = TestContext()
    let readStarted = DispatchSemaphore(value: 0)
    let finishRead = DispatchSemaphore(value: 0)
    let updated = DispatchSemaphore(value: 0)
    let seenInRead = Box<Int?>(nil)

    Thread {
      context.store.read { state in
        readStarted.signal()
        finishRead.wait()
        seenInRead.value = state.value
      }
    }.start()
    readStarted.wait()

    Thread {
      context.store.update(Add(amount: 1))
      updated.signal()
    }.start()

    #expect(updated.wait(timeout: .now() + 0.2) == .timedOut)
    finishRead.signal()
    #expect(updated.wait(timeout: .now() + 2) == .success)
    #expect(seenInRead.value == 0)
    #expect(context.store.state.value == 1)
  }

  @Test("Observers see the state before and after each update, in order")
  func observersSeeBeforeAndAfter() {
    let store = TestStore(initial: Counter())
    var seen: [(Int, Int)] = []
    store.observe { before, after in
      seen.append((before.value, after.value))
    }

    store.update(Add(amount: 1))
    store.update(Add(amount: 2))

    #expect(seen.map(\.0) == [0, 1])
    #expect(seen.map(\.1) == [1, 3])
  }

  @Test("Observers run in the order they were added, and only for later updates")
  func observerOrder() {
    let store = TestStore(initial: Counter())
    var calls: [String] = []
    store.update(Add(amount: 1))
    store.observe { _, _ in calls.append("first") }
    store.observe { _, _ in calls.append("second") }

    store.update(Add(amount: 1))

    #expect(calls == ["first", "second"])
  }

  @Test("Updates from many threads are all applied")
  func concurrentUpdates() async {
    let store = TestStore(initial: Counter())
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<1000 {
        group.addTask { store.update(Add(amount: 1)) }
      }
    }
    #expect(store.state.value == 1000)
  }

  @Test("Observers see updates from many threads one at a time, in the order applied")
  func observersAreSerialized() async {
    let store = TestStore(initial: Counter())
    let afters = Box<[Int]>([])
    let inside = Box(0)
    let overlapped = Box(false)
    store.observe { before, after in
      inside.mutate { $0 += 1 }
      if inside.value > 1 {
        overlapped.value = true
      }
      // Each update adds one, so in apply order every `after` is one more
      // than the `before` the previous call reported.
      afters.mutate { $0.append(after.value) }
      #expect(after.value == before.value + 1)
      inside.mutate { $0 -= 1 }
    }

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<500 {
        group.addTask { store.update(Add(amount: 1)) }
      }
    }

    #expect(overlapped.value == false)
    #expect(afters.value == Array(1...500))
  }

  @Test("An observer can update the store again without deadlocking")
  func observerUpdatesAgain() {
    let store = TestStore(initial: Counter())
    var seen: [Int] = []
    store.observe { _, after in
      seen.append(after.value)
      if after.value == 1 {
        store.update(Add(amount: 10))
      }
    }

    store.update(Add(amount: 1))

    #expect(store.state.value == 11)
    #expect(seen == [1, 11])
  }

  @Test("Every observer hears about an update made by an observer after the one in progress")
  func observerUpdateIsHeardInOrder() {
    let store = TestStore(initial: Counter())
    var first: [String] = []
    var second: [String] = []
    var valueSeenByUpdater: Int?
    store.observe { before, after in
      first.append("\(before.value)→\(after.value)")
      if after.value == 1 {
        store.update(Add(amount: 10))
        // The update is applied before it returns.
        valueSeenByUpdater = store.state.value
      }
    }
    store.observe { before, after in
      second.append("\(before.value)→\(after.value)")
    }

    store.update(Add(amount: 1))

    #expect(valueSeenByUpdater == 11)
    #expect(first == ["0→1", "1→11"])
    #expect(second == ["0→1", "1→11"])
    #expect(store.state.value == 11)
  }

  @Test("Updates made by several observers, and by their nested updates, are heard in order")
  func chainedObserverUpdates() {
    let store = TestStore(initial: Counter())
    var heard: [[String]] = [[], [], []]
    store.observe { before, after in
      heard[0].append("\(before.value)→\(after.value)")
      if after.value == 1 {
        store.update(Add(amount: 10))
      }
    }
    store.observe { before, after in
      heard[1].append("\(before.value)→\(after.value)")
      if after.value == 1 {
        store.update(Add(amount: 100))
      }
      if after.value == 11 {
        store.update(Add(amount: 1_000))
      }
    }
    store.observe { before, after in
      heard[2].append("\(before.value)→\(after.value)")
    }

    store.update(Add(amount: 1))

    // 0→1 is heard first. The updates it caused are heard in the order they
    // were applied (+10, then +100), then the one +10 caused (+1000). Each
    // `before` is the previous `after`, and the last `after` is the state.
    let expected = ["0→1", "1→11", "11→111", "111→1111"]
    #expect(heard[0] == expected)
    #expect(heard[1] == expected)
    #expect(heard[2] == expected)
    #expect(store.state.value == 1_111)
  }

  @Test("After an observer's nested update, a later top-level update notifies straight away")
  func notifyingResetsAfterNestedUpdates() {
    let store = TestStore(initial: Counter())
    var heard: [Int] = []
    store.observe { _, after in
      heard.append(after.value)
      if after.value == 1 {
        store.update(Add(amount: 1))
      }
    }

    store.update(Add(amount: 1))
    #expect(heard == [1, 2])

    store.update(Add(amount: 5))
    #expect(heard == [1, 2, 7])
  }

  // MARK: - dispatch

  @Test("dispatch runs the action before returning, so a read straight after sees it")
  func dispatchIsSynchronous() {
    let context = TestContext()
    context.store.dispatch(Run { $0.store.update(Add(amount: 1)) }, in: context)
    #expect(context.store.state.value == 1)
  }

  @Test("Actions dispatched from many threads never interleave")
  func dispatchesAreSerialized() async {
    let context = TestContext()
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<1000 {
        group.addTask {
          context.store.dispatch(
            Run { context in
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
    #expect(context.store.state.value == 1000)
  }

  @Test("A dispatch on another thread waits for the running action to finish")
  func dispatchWaitsForRunningAction() {
    let context = TestContext()
    let started = DispatchSemaphore(value: 0)
    let proceed = DispatchSemaphore(value: 0)
    let secondDone = DispatchSemaphore(value: 0)
    let firstDone = DispatchSemaphore(value: 0)

    onThread {
      context.store.dispatch(
        Run { context in
          context.store.update(Log(entry: "first start"))
          started.signal()
          // Only a test waits inside an action, to hold it open.
          _ = proceed.wait(timeout: .now() + 5)
          context.store.update(Log(entry: "first end"))
        },
        in: context
      )
      firstDone.signal()
    }
    started.wait()

    onThread {
      context.store.dispatch(Run { $0.store.update(Log(entry: "second")) }, in: context)
      secondDone.signal()
    }

    #expect(secondDone.wait(timeout: .now() + 0.1) == .timedOut)
    proceed.signal()
    #expect(secondDone.wait(timeout: .now() + 5) == .success)
    firstDone.wait()
    #expect(context.store.state.log == ["first start", "first end", "second"])
  }

  @Test("A read on another thread during an action sees none of it or all of it")
  func readsSeeWholeActions() {
    let context = TestContext()
    let started = DispatchSemaphore(value: 0)
    let proceed = DispatchSemaphore(value: 0)
    let readDone = DispatchSemaphore(value: 0)
    let actionDone = DispatchSemaphore(value: 0)
    let read = Box<[String]?>(nil)

    onThread {
      context.store.dispatch(
        Run { context in
          context.store.update(Log(entry: "a"))
          started.signal()
          _ = proceed.wait(timeout: .now() + 5)
          context.store.update(Log(entry: "b"))
        },
        in: context
      )
      actionDone.signal()
    }
    started.wait()

    onThread {
      read.value = context.store.state.log
      readDone.signal()
    }

    #expect(readDone.wait(timeout: .now() + 0.1) == .timedOut)
    proceed.signal()
    #expect(readDone.wait(timeout: .now() + 5) == .success)
    actionDone.wait()
    #expect(read.value == ["a", "b"])
  }

  @Test("A dispatch from inside an action runs straight away, inside it")
  func nestedDispatchRunsInline() {
    let context = TestContext()
    context.store.dispatch(
      Run { context in
        context.store.update(Log(entry: "outer start"))
        context.store.dispatch(Run { $0.store.update(Log(entry: "inner")) }, in: context)
        context.store.update(Log(entry: "outer end"))
      },
      in: context
    )
    #expect(context.store.state.log == ["outer start", "inner", "outer end"])
  }

  // MARK: - deferUntilUnlocked

  @Test("Deferred work runs after the action, before dispatch returns")
  func deferredWorkRunsAfterAction() {
    let context = TestContext()
    context.store.dispatch(
      Run { context in
        context.store.deferUntilUnlocked {
          context.store.update(Log(entry: "deferred"))
        }
        context.store.update(Log(entry: "action"))
      },
      in: context
    )
    #expect(context.store.state.log == ["action", "deferred"])
  }

  @Test("Deferred work runs with the store unlocked")
  func deferredWorkRunsUnlocked() {
    let context = TestContext()
    let otherThreadUpdated = Box(false)

    context.store.dispatch(
      Run { context in
        context.store.deferUntilUnlocked {
          // Waits on another thread that needs the lock. If the store were
          // still locked, this would time out.
          let done = DispatchSemaphore(value: 0)
          onThread {
            context.store.update(Log(entry: "other thread"))
            done.signal()
          }
          otherThreadUpdated.value = done.wait(timeout: .now() + 2) == .success
        }
      },
      in: context
    )

    #expect(otherThreadUpdated.value)
    #expect(context.store.state.log == ["other thread"])
  }

  @Test("Work deferred in nested dispatches runs once the outermost finishes, in order")
  func nestedDeferredWorkOrder() {
    let context = TestContext()
    context.store.dispatch(
      Run { context in
        context.store.deferUntilUnlocked { context.store.update(Log(entry: "A")) }
        context.store.dispatch(
          Run { context in
            context.store.deferUntilUnlocked { context.store.update(Log(entry: "B")) }
            context.store.update(Log(entry: "inner"))
          },
          in: context
        )
        context.store.deferUntilUnlocked { context.store.update(Log(entry: "C")) }
        context.store.update(Log(entry: "outer"))
      },
      in: context
    )
    #expect(context.store.state.log == ["inner", "outer", "A", "B", "C"])
  }

  @Test("Deferred work can dispatch actions that defer work of their own")
  func deferredWorkCanDispatch() {
    let context = TestContext()
    context.store.dispatch(
      Run { context in
        context.store.deferUntilUnlocked {
          context.store.dispatch(
            Run { context in
              context.store.deferUntilUnlocked { context.store.update(Log(entry: "second deferred")) }
              context.store.update(Log(entry: "second action"))
            },
            in: context
          )
          context.store.update(Log(entry: "first deferred end"))
        }
        context.store.update(Log(entry: "first action"))
      },
      in: context
    )
    #expect(context.store.state.log == [
      "first action", "second action", "second deferred", "first deferred end"
    ])
  }

  @Test("Work deferred by a dispatch inside deferred work runs before that dispatch returns")
  func nestedDeferredWorkRunsBeforeLaterDeferredWork() {
    // A and B are deferred by one action. A dispatches an action that defers
    // C. C belongs to that inner dispatch, so it has run by the time the
    // dispatch returns, before A goes on and before B.
    let context = TestContext()
    context.store.dispatch(
      Run { context in
        context.store.deferUntilUnlocked {
          context.store.update(Log(entry: "A start"))
          context.store.dispatch(
            Run { context in
              context.store.deferUntilUnlocked {
                context.store.update(Log(entry: "C"))
              }
            },
            in: context
          )
          context.store.update(Log(entry: "A end"))
        }
        context.store.deferUntilUnlocked {
          context.store.update(Log(entry: "B"))
        }
      },
      in: context
    )
    #expect(context.store.state.log == ["A start", "C", "A end", "B"])
  }

  @Test("Work deferred by an observer runs after the update, unlocked")
  func observerDeferredWork() {
    let store = TestStore(initial: Counter())
    let otherThreadRead = Box(false)
    store.observe { before, after in
      // Only for the first update. The deferred work updates the store too.
      guard before.value == 0, after.value == 1 else {
        return
      }
      store.deferUntilUnlocked {
        let done = DispatchSemaphore(value: 0)
        onThread {
          _ = store.state
          done.signal()
        }
        otherThreadRead.value = done.wait(timeout: .now() + 2) == .success
        store.update(Log(entry: "deferred"))
      }
    }

    store.update(Add(amount: 1))

    #expect(otherThreadRead.value)
    #expect(store.state.log == ["deferred"])
  }

  @Test("Work deferred outside an update or dispatch runs straight away")
  func deferOutsideRunsNow() {
    let store = TestStore(initial: Counter())
    var ran = false
    store.deferUntilUnlocked { ran = true }
    #expect(ran)
  }

  @Test("Work deferred on one thread doesn't run on another thread's dispatch")
  func deferredWorkStaysOnItsThread() {
    let context = TestContext()
    let started = DispatchSemaphore(value: 0)
    let proceed = DispatchSemaphore(value: 0)
    let firstDone = DispatchSemaphore(value: 0)
    let deferredThread = Box<Thread?>(nil)
    let firstThread = Box<Thread?>(nil)

    onThread {
      firstThread.value = Thread.current
      context.store.dispatch(
        Run { context in
          context.store.deferUntilUnlocked { deferredThread.value = Thread.current }
          started.signal()
          _ = proceed.wait(timeout: .now() + 5)
        },
        in: context
      )
      firstDone.signal()
    }
    started.wait()

    let secondDone = DispatchSemaphore(value: 0)
    onThread {
      context.store.dispatch(Run { _ in }, in: context)
      secondDone.signal()
    }
    proceed.signal()
    firstDone.wait()
    secondDone.wait()

    #expect(deferredThread.value === firstThread.value)
  }

  // MARK: - dispatch results and read

  @Test("dispatch returns what the action returned")
  func dispatchReturnsResult() {
    let context = TestContext()
    context.store.update(SetValue(value: 4))

    let previous = context.store.dispatch(AddReturningPrevious(amount: 3), in: context)

    #expect(previous == 4)
    #expect(context.store.state.value == 7)
  }

  @Test("Results from many threads each see a different state, so no two read the same")
  func dispatchResultsAreAtomic() async {
    let context = TestContext()

    let previous = await withTaskGroup(of: Int.self) { group in
      for _ in 0..<200 {
        group.addTask {
          context.store.dispatch(AddReturningPrevious(amount: 1), in: context)
        }
      }
      var values: [Int] = []
      for await value in group {
        values.append(value)
      }
      return values
    }

    #expect(Set(previous) == Set(0..<200))
    #expect(context.store.state.value == 200)
  }

  @Test("read returns part of the state")
  func readReturnsPart() {
    let context = TestContext()
    context.store.update(SetValue(value: 9))

    #expect(context.store.read { $0.value } == 9)
  }

  @Test("An update on another thread waits for a read in progress")
  func updateWaitsForRead() {
    let context = TestContext()
    let reading = DispatchSemaphore(value: 0)
    let proceed = DispatchSemaphore(value: 0)
    let updated = DispatchSemaphore(value: 0)
    let seenDuringRead = Box<Int?>(nil)

    onThread {
      context.store.read { state in
        reading.signal()
        _ = proceed.wait(timeout: .now() + 5)
        seenDuringRead.value = state.value
      }
    }
    reading.wait()
    onThread {
      context.store.update(SetValue(value: 1))
      updated.signal()
    }

    #expect(updated.wait(timeout: .now() + 0.2) == .timedOut)
    proceed.signal()
    #expect(updated.wait(timeout: .now() + 5) == .success)
    #expect(seenDuringRead.value == 0)
    #expect(context.store.state.value == 1)
  }
}
