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

  /// Every value that concurrent writers store reaches subscribers once, in
  /// the order it was stored, and the last emission is the stored value.
  @Test
  func concurrentWrites_emitEveryStoredValueInOrder() {
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
  func writerNeverWaitsOnASubscriber() async {
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

    let background = Task.detached { [superwall] in
      superwall.subscriptionStatus = self.status("blocking")
    }
    subscriberEntered.wait()

    // The emitting thread is stuck inside its subscriber. This write must
    // return without waiting for it.
    let writeReturned = Task.detached { [superwall] in
      superwall.subscriptionStatus = self.status("meanwhile")
      return true
    }
    let didReturn = await withTaskGroup(of: Bool.self) { group -> Bool in
      group.addTask { await writeReturned.value }
      group.addTask {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        return false
      }
      let first = await group.next() ?? false
      group.cancelAll()
      return first
    }
    #expect(didReturn, "the writer waited on a blocked subscriber")

    releaseSubscriber.signal()
    await background.value
    #expect(superwall.subscriptionStatus == status("meanwhile"))
    cancellable.cancel()
  }

  /// Reads and writes from many threads at once don't tear or crash.
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
