//
//  OrderedDeliveryTests.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Values shared with other threads.
private final class Recorded<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var _values: [Value] = []
  private var running = 0
  private var _maxRunning = 0

  var values: [Value] {
    lock.lock()
    defer { lock.unlock() }
    return _values
  }

  var maxRunning: Int {
    lock.lock()
    defer { lock.unlock() }
    return _maxRunning
  }

  func start(_ value: Value) {
    lock.lock()
    _values.append(value)
    running += 1
    _maxRunning = max(_maxRunning, running)
    lock.unlock()
  }

  func finish() {
    lock.lock()
    running -= 1
    lock.unlock()
  }
}

private struct Count {
  var value = 0
}

private struct Increment: Reducer {
  func reduce(_ state: Count) -> Count {
    Count(value: state.value + 1)
  }
}

private typealias CountStore = StateStore<Void, Count>

/// Sends every update to `receive` once the store is unlocked, as
/// `ConfigManager` does with `configState`.
private func deliverUpdates(
  of store: CountStore,
  to receive: @escaping (Int) -> Void
) {
  let delivery = OrderedDelivery<Int>(receive)
  store.observe { [weak store] _, after in
    delivery.add(after.value)
    store?.deferUntilUnlocked {
      delivery.deliver()
    }
  }
}

@Suite("OrderedDelivery")
struct OrderedDeliveryTests {
  @Test("Values are delivered in the order they were added")
  func deliversInOrder() {
    let recorded = Recorded<Int>()
    let delivery = OrderedDelivery<Int> { value in
      recorded.start(value)
      recorded.finish()
    }

    for value in 0..<5 {
      delivery.add(value)
    }
    #expect(recorded.values.isEmpty)
    delivery.deliver()
    #expect(recorded.values == Array(0..<5))

    delivery.add(5)
    delivery.deliver()
    #expect(recorded.values == Array(0..<6))
  }

  @Test("deliver with nothing waiting does nothing")
  func deliverWhenEmpty() {
    let recorded = Recorded<Int>()
    let delivery = OrderedDelivery<Int> { recorded.start($0) }
    delivery.deliver()
    delivery.deliver()
    #expect(recorded.values.isEmpty)
  }

  @Test("A value added by the receiver is delivered after the current one returns")
  func receiverCanAddMore() {
    let recorded = Recorded<String>()
    var delivery: OrderedDelivery<String>!
    delivery = OrderedDelivery<String> { value in
      recorded.start("start \(value)")
      if value == "a" {
        delivery.add("b")
        delivery.deliver()
        // Not delivered inside this one.
        #expect(recorded.values == ["start a"])
      }
      recorded.start("end \(value)")
    }

    delivery.add("a")
    delivery.deliver()

    #expect(recorded.values == ["start a", "end a", "start b", "end b"])
  }

  @Test("With nested delivery, a value the receiver adds is delivered before its deliver call returns")
  func nestedDelivery() {
    let recorded = Recorded<String>()
    var delivery: OrderedDelivery<String>!
    delivery = OrderedDelivery<String>(deliversNestedValues: true) { value in
      recorded.start("start \(value)")
      if value == "a" {
        delivery.add("b")
        delivery.deliver()
        #expect(recorded.values == ["start a", "start b", "end b"])
      }
      recorded.start("end \(value)")
    }

    delivery.add("a")
    delivery.deliver()
    #expect(recorded.values == ["start a", "start b", "end b", "end a"])

    // It's free for the next delivery.
    delivery.add("c")
    delivery.deliver()
    #expect(recorded.values.suffix(2) == ["start c", "end c"])
  }

  @Test("With nested delivery, a deliver call from another thread still doesn't wait")
  func nestedDeliveryFromAnotherThread() {
    let recorded = Recorded<Int>()
    let inReceiver = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let delivery = OrderedDelivery<Int>(deliversNestedValues: true) { value in
      recorded.start(value)
      if value == 0 {
        inReceiver.signal()
        release.wait()
      }
    }

    delivery.add(0)
    let firstDone = DispatchSemaphore(value: 0)
    Thread {
      delivery.deliver()
      firstDone.signal()
    }
    .start()
    inReceiver.wait()

    let secondDone = DispatchSemaphore(value: 0)
    Thread {
      delivery.add(1)
      delivery.deliver()
      secondDone.signal()
    }
    .start()
    #expect(secondDone.wait(timeout: .now() + 2) == .success)
    #expect(recorded.values == [0])

    release.signal()
    #expect(firstDone.wait(timeout: .now() + 2) == .success)
    #expect(recorded.values == [0, 1])
  }

  @Test("Values added from many threads are each delivered once, never two at a time")
  func concurrentDeliveries() async {
    let recorded = Recorded<Int>()
    let delivery = OrderedDelivery<Int> { value in
      recorded.start(value)
      Thread.sleep(forTimeInterval: 0.0001)
      recorded.finish()
    }

    await withTaskGroup(of: Void.self) { group in
      for value in 0..<300 {
        group.addTask {
          delivery.add(value)
          delivery.deliver()
        }
      }
    }

    // Every deliver call has returned, and the one that was delivering
    // returned only once nothing was left.
    #expect(recorded.values.count == 300)
    #expect(Set(recorded.values).count == 300)
    #expect(recorded.maxRunning == 1)
  }

  @Test("A deliver call while another thread is delivering doesn't wait for it")
  func deliverDoesNotWaitForAnotherThread() {
    let recorded = Recorded<Int>()
    let inReceiver = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let delivery = OrderedDelivery<Int> { value in
      recorded.start(value)
      if value == 0 {
        inReceiver.signal()
        release.wait()
      }
    }

    delivery.add(0)
    let firstDone = DispatchSemaphore(value: 0)
    Thread {
      delivery.deliver()
      firstDone.signal()
    }
    .start()
    inReceiver.wait()

    // The other thread is inside the receiver. This returns at once, and that
    // thread delivers 1 once 0 returns.
    let secondDone = DispatchSemaphore(value: 0)
    Thread {
      delivery.add(1)
      delivery.deliver()
      secondDone.signal()
    }
    .start()
    #expect(secondDone.wait(timeout: .now() + 2) == .success)
    #expect(recorded.values == [0])

    release.signal()
    #expect(firstDone.wait(timeout: .now() + 2) == .success)
    #expect(recorded.values == [0, 1])
  }

  // MARK: - With a store

  @Test("Store updates on one thread are delivered before the update returns")
  func storeUpdatesDeliveredBeforeReturning() {
    let store = CountStore(initial: Count())
    let recorded = Recorded<Int>()
    deliverUpdates(of: store) { recorded.start($0) }

    store.update(Increment())
    #expect(recorded.values == [1])
    store.update(Increment())
    #expect(recorded.values == [1, 2])
  }

  @Test("The receiver runs with the store unlocked")
  func receiverRunsUnlocked() {
    let store = CountStore(initial: Count())
    let otherThreadRead = LockedBox(false)
    deliverUpdates(of: store) { _ in
      let done = DispatchSemaphore(value: 0)
      Thread {
        _ = store.state
        done.signal()
      }
      .start()
      otherThreadRead.set(done.wait(timeout: .now() + 2) == .success)
    }

    store.update(Increment())
    #expect(otherThreadRead.value)
  }

  @Test("A receiver that takes a lock can't deadlock with a thread holding it that reads the store")
  func noLockOrderDeadlock() {
    // As with configState and the MMP: the receiver takes `otherLock`, and
    // another thread holds `otherLock` while reading the store.
    let store = CountStore(initial: Count())
    let otherLock = NSLock()
    let receiverWaiting = DispatchSemaphore(value: 0)
    let recorded = Recorded<Int>()
    deliverUpdates(of: store) { value in
      receiverWaiting.signal()
      otherLock.lock()
      recorded.start(value)
      otherLock.unlock()
    }

    otherLock.lock()
    let updated = DispatchSemaphore(value: 0)
    Thread {
      store.update(Increment())
      updated.signal()
    }
    .start()
    receiverWaiting.wait()

    // The updating thread is waiting for `otherLock` in the receiver. If it
    // still held the store's lock, this read would never return.
    let read = DispatchSemaphore(value: 0)
    let readValue = LockedBox(0)
    Thread {
      readValue.set(store.state.value)
      read.signal()
    }
    .start()
    #expect(read.wait(timeout: .now() + 2) == .success)
    #expect(readValue.value == 1)

    otherLock.unlock()
    #expect(updated.wait(timeout: .now() + 2) == .success)
    #expect(recorded.values == [1])
  }

  @Test("Updates from many threads are delivered in the order they were applied")
  func storeUpdatesDeliveredInOrder() async {
    let store = CountStore(initial: Count())
    let recorded = Recorded<Int>()
    deliverUpdates(of: store) { value in
      recorded.start(value)
      recorded.finish()
    }

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<300 {
        group.addTask {
          store.update(Increment())
        }
      }
    }

    // Each update adds one, so the order applied is 1, 2, 3...
    #expect(recorded.values == Array(1...300))
    #expect(recorded.maxRunning == 1)
  }

  @Test("An update made by the receiver is delivered after the one it's handling")
  func receiverUpdatesStore() {
    let store = CountStore(initial: Count())
    let recorded = Recorded<String>()
    deliverUpdates(of: store) { value in
      recorded.start("start \(value)")
      if value == 1 {
        store.update(Increment())
        #expect(store.state.value == 2)
      }
      recorded.start("end \(value)")
    }

    store.update(Increment())

    #expect(recorded.values == ["start 1", "end 1", "start 2", "end 2"])
  }
}

/// A value shared with other threads.
private final class LockedBox<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: Value

  init(_ value: Value) {
    _value = value
  }

  var value: Value {
    lock.lock()
    defer { lock.unlock() }
    return _value
  }

  func set(_ value: Value) {
    lock.lock()
    _value = value
    lock.unlock()
  }
}
