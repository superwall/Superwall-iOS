//
//  SubscriptionStatusEmissionTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 2026-09-16.
//
// swiftlint:disable all

@testable import SuperwallKit
import Combine
import Testing
import Foundation

/// How `$subscriptionStatus` emits when the status is read and written from
/// more than one thread at once.
@Suite(.serialized)
final class SubscriptionStatusEmissionTests {
  private let dependencyContainer: DependencyContainer
  private let superwall: Superwall

  init() {
    dependencyContainer = DependencyContainer(cache: CacheMock())
    superwall = Superwall(dependencyContainer: dependencyContainer)
  }

  private func status(_ id: String) -> SubscriptionStatus {
    return .active([Entitlement(id: id, type: .serviceLevel, isActive: true)])
  }

  /// Every value that concurrent writers store reaches subscribers exactly
  /// once, and the last emission is the stored value. Ordering is covered by
  /// `reentrantAssignment_isEmittedAfterTheTriggeringValue`, where the store
  /// order is known.
  @Test
  func concurrentWrites_emitEveryStoredValueOnce() {
    let emissions = Locked<[SubscriptionStatus]>([])
    let cancellable = superwall.$subscriptionStatus
      .dropFirst()
      .sink { emittedStatus in emissions.mutate { $0.append(emittedStatus) } }

    let writeCount = 200
    DispatchQueue.concurrentPerform(iterations: writeCount) { index in
      superwall.subscriptionStatus = status("entitlement_\(index)")
    }

    let emitted = emissions.value
    #expect(emitted.count == writeCount, "each distinct value is emitted exactly once")
    let emittedIds = emitted.compactMap { emittedStatus -> String? in
      guard case .active(let entitlements) = emittedStatus else {
        return nil
      }
      return entitlements.first?.id
    }
    #expect(Set(emittedIds).count == writeCount, "no value is emitted twice")
    #expect(emitted.last == superwall.subscriptionStatus, "the publisher never ends behind storage")
    cancellable.cancel()
  }

  /// A subscriber that assigns the status from inside an emission neither
  /// deadlocks nor reorders: its value is emitted after the one that
  /// triggered it.
  @Test
  func reentrantAssignment_isEmittedAfterTheTriggeringValue() {
    let emissions = Locked<[SubscriptionStatus]>([])
    let cancellable = superwall.$subscriptionStatus
      .dropFirst()
      .sink { [superwall] emittedStatus in
        emissions.mutate { $0.append(emittedStatus) }
        if emittedStatus == self.status("first") {
          superwall.subscriptionStatus = self.status("second")
        }
      }

    superwall.subscriptionStatus = status("first")

    #expect(emissions.value == [status("first"), status("second")])
    #expect(superwall.subscriptionStatus == status("second"))
    cancellable.cancel()
  }

  /// A writer whose value is emitted by another thread's drain doesn't wait
  /// for that thread's subscribers, so a subscriber blocked on the writer's
  /// thread can't deadlock it.
  @Test
  func writerNeverWaitsOnASubscriber() {
    let subscriberEntered = DispatchSemaphore(value: 0)
    let releaseSubscriber = DispatchSemaphore(value: 0)
    let cancellable = superwall.$subscriptionStatus
      .dropFirst()
      .sink { [superwall] emittedStatus in
        if emittedStatus == self.status("blocking") {
          subscriberEntered.signal()
          releaseSubscriber.wait()
          _ = superwall.subscriptionStatus
        }
      }

    // Plain threads rather than tasks: the blocked subscriber must not take
    // a cooperative-pool thread with it, and every wait is bounded so a
    // regression fails the test instead of hanging the run.
    let backgroundFinished = DispatchSemaphore(value: 0)
    DispatchQueue.global().async { [superwall] in
      superwall.subscriptionStatus = self.status("blocking")
      backgroundFinished.signal()
    }
    #expect(subscriberEntered.wait(timeout: .now() + 2) == .success, "the subscriber never ran")

    // The emitting thread is stuck inside its subscriber. This write must
    // return without waiting for it.
    let writeReturned = DispatchSemaphore(value: 0)
    DispatchQueue.global().async { [superwall] in
      superwall.subscriptionStatus = self.status("meanwhile")
      writeReturned.signal()
    }
    #expect(writeReturned.wait(timeout: .now() + 2) == .success, "the writer waited on a blocked subscriber")

    releaseSubscriber.signal()
    #expect(backgroundFinished.wait(timeout: .now() + 2) == .success, "the drain never finished")
    #expect(superwall.subscriptionStatus == status("meanwhile"))
    cancellable.cancel()
  }

  /// Reads and writes from many threads at once don't tear or crash. This is
  /// a smoke test meant for a Thread Sanitizer run; the locking itself is
  /// pinned by the tests above.
  @Test
  func concurrentReadsAndWrites_staySafe() {
    DispatchQueue.concurrentPerform(iterations: 500) { index in
      if index.isMultiple(of: 2) {
        superwall.subscriptionStatus = status("entitlement_\(index)")
      } else {
        _ = superwall.subscriptionStatus
        _ = superwall.assignedSubscriptionStatus
      }
    }
    if case .active(let entitlements) = superwall.subscriptionStatus {
      #expect(entitlements.count == 1)
    } else {
      Issue.record("expected an active status")
    }
    #expect(superwall.assignedSubscriptionStatus == superwall.subscriptionStatus)
  }
}

/// A value guarded by a lock, for collecting emissions off arbitrary threads.
private final class Locked<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: Value

  init(_ value: Value) {
    storage = value
  }

  var value: Value {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }

  func mutate(_ body: (inout Value) -> Void) {
    lock.lock()
    defer { lock.unlock() }
    body(&storage)
  }
}
