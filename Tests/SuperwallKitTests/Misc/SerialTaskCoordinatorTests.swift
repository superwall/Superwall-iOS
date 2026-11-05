//
//  SerialTaskCoordinatorTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 11/09/2026.
//

import Foundation
import Testing

@testable import SuperwallKit

@Suite("SerialTaskCoordinator Tests")
struct SerialTaskCoordinatorTests {
  /// Records the priority an operation ran at.
  private actor PriorityRecorder {
    private(set) var recorded: TaskPriority?

    func record(_ priority: TaskPriority) {
      recorded = priority
    }
  }

  /// Records the order operations ran in and how many ran at the same time.
  private actor Recorder {
    private(set) var order: [Int] = []
    private(set) var maxRunningAtOnce = 0
    private var runningAtOnce = 0

    func didStart(_ id: Int) {
      order.append(id)
      runningAtOnce += 1
      maxRunningAtOnce = max(maxRunningAtOnce, runningAtOnce)
    }

    private(set) var finished: [Int] = []

    func didFinish(_ id: Int? = nil) {
      runningAtOnce -= 1
      if let id = id {
        finished.append(id)
      }
    }
  }

  @Test("Operations run in the order they were enqueued")
  func runsOperationsInOrder() async {
    let coordinator = SerialTaskCoordinator()
    let recorder = Recorder()

    for id in 0..<20 {
      coordinator.enqueue {
        await recorder.didStart(id)
        await Task.yield()
        await recorder.didFinish()
      }
    }
    await coordinator.flush()

    let order = await recorder.order
    let maxRunningAtOnce = await recorder.maxRunningAtOnce
    #expect(order == Array(0..<20))
    #expect(maxRunningAtOnce == 1)
  }

  @Test("Only one operation runs at a time when enqueued from many threads")
  func runsOneOperationAtATimeAcrossThreads() async {
    let coordinator = SerialTaskCoordinator()
    let recorder = Recorder()
    let operationCount = 200

    await withCheckedContinuation { continuation in
      let group = DispatchGroup()

      for id in 0..<operationCount {
        group.enter()
        let queue = DispatchQueue.global(qos: id.isMultiple(of: 2) ? .userInitiated : .utility)
        queue.async {
          coordinator.enqueue {
            await recorder.didStart(id)
            await Task.yield()
            await recorder.didFinish()
          }
          group.leave()
        }
      }

      group.notify(queue: .global()) {
        continuation.resume()
      }
    }
    await coordinator.flush()

    let order = await recorder.order
    let maxRunningAtOnce = await recorder.maxRunningAtOnce
    // Every operation runs exactly once, and never alongside another one. If the
    // swap of the task reference weren't serialized, two operations enqueued at
    // the same time would each wait on the same predecessor and then overlap.
    #expect(order.count == operationCount)
    #expect(Set(order).count == operationCount)
    #expect(maxRunningAtOnce == 1)
  }

  @Test("Operations enqueued after the queue has drained still run")
  func runsOperationsEnqueuedAfterDraining() async {
    let coordinator = SerialTaskCoordinator()
    let recorder = Recorder()

    coordinator.enqueue {
      await recorder.didStart(0)
      await recorder.didFinish()
    }
    await coordinator.flush()

    coordinator.enqueue {
      await recorder.didStart(1)
      await recorder.didFinish()
    }
    await coordinator.flush()

    let order = await recorder.order
    #expect(order == [0, 1])
  }

  @Test("Operations run at the priority of whoever enqueued them")
  func runsAtEnqueuersPriority() async {
    // The coordinator is made here, so the task draining its stream takes this
    // context's priority — the stand-in for an app calling `configure()`. If
    // that's already `.high`, the assertion below can't tell the two apart.
    #expect(Task.currentPriority < .high)
    let coordinator = SerialTaskCoordinator()
    let recorder = PriorityRecorder()

    await Task(priority: .high) {
      coordinator.enqueue {
        await recorder.record(Task.currentPriority)
      }
    }
    .value
    await coordinator.flush()

    let recorded = await recorder.recorded
    #expect(recorded == .high)
  }

  @Test("run returns only once its operation has finished")
  func runWaitsForItsOperation() async {
    let coordinator = SerialTaskCoordinator()
    let recorder = Recorder()

    await coordinator.run {
      await recorder.didStart(0)
      for _ in 0..<10 {
        await Task.yield()
      }
      await recorder.didFinish(0)
    }

    // Recorded only once the operation finished.
    #expect(await recorder.finished == [0])
  }

  @Test("run waits for operations enqueued before it")
  func runWaitsBehindEarlierOperations() async {
    let coordinator = SerialTaskCoordinator()
    let recorder = Recorder()
    let gate = Gate()

    coordinator.enqueue {
      await gate.wait()
      await recorder.didStart(0)
      await recorder.didFinish()
    }

    async let ran: Void = coordinator.run {
      await recorder.didStart(1)
      await recorder.didFinish()
    }
    // The first operation is still waiting, so `run`'s can't have started.
    for _ in 0..<50 {
      await Task.yield()
    }
    #expect(await recorder.order.isEmpty)

    await gate.open()
    await ran

    #expect(await recorder.order == [0, 1])
    #expect(await recorder.maxRunningAtOnce == 1)
  }

  @Test("Concurrent run calls from many threads each run once, one at a time")
  func concurrentRunsDontOverlap() async {
    let coordinator = SerialTaskCoordinator()
    let recorder = Recorder()
    let callCount = 200

    await withTaskGroup(of: Void.self) { group in
      for id in 0..<callCount {
        group.addTask(priority: id.isMultiple(of: 2) ? .high : .low) {
          await coordinator.run {
            await recorder.didStart(id)
            await Task.yield()
            await recorder.didFinish()
          }
        }
      }
    }

    // Every `run` returned, so every operation has finished.
    let order = await recorder.order
    #expect(order.count == callCount)
    #expect(Set(order).count == callCount)
    #expect(await recorder.maxRunningAtOnce == 1)
  }

  @Test("run returns in the order the calls were made on one task")
  func sequentialRunsKeepOrder() async {
    let coordinator = SerialTaskCoordinator()
    let recorder = Recorder()

    for id in 0..<20 {
      if id.isMultiple(of: 3) {
        await coordinator.run {
          await recorder.didStart(id)
          await recorder.didFinish()
        }
      } else {
        coordinator.enqueue {
          await recorder.didStart(id)
          await recorder.didFinish()
        }
      }
    }
    await coordinator.flush()

    #expect(await recorder.order == Array(0..<20))
  }

  @Test("An operation can enqueue another, which runs after it")
  func operationCanEnqueueFollowUp() async {
    let coordinator = SerialTaskCoordinator()
    let recorder = Recorder()

    await coordinator.run {
      coordinator.enqueue {
        await recorder.didStart(1)
        await recorder.didFinish()
      }
      await recorder.didStart(0)
      await Task.yield()
      await recorder.didFinish()
    }
    await coordinator.flush()

    #expect(await recorder.order == [0, 1])
    #expect(await recorder.maxRunningAtOnce == 1)
  }

  @Test("flush waits for operations enqueued before it")
  func flushWaitsForEarlierOperations() async {
    let coordinator = SerialTaskCoordinator()
    let recorder = Recorder()
    let gate = Gate()

    coordinator.enqueue {
      await recorder.didStart(0)
      await recorder.didFinish()
    }
    await coordinator.flush()
    #expect(await recorder.order == [0])

    // Held until opened, so a flush that waited on it wouldn't return.
    coordinator.enqueue {
      await gate.wait()
      await recorder.didStart(1)
      await recorder.didFinish()
    }
    let earlierFlush = Task {
      await coordinator.flush()
    }
    for _ in 0..<50 {
      await Task.yield()
    }
    #expect(await recorder.order == [0])

    await gate.open()
    await earlierFlush.value
    #expect(await recorder.order == [0, 1])
  }

  @Test("flush on an empty coordinator returns")
  func flushWhenEmpty() async {
    let coordinator = SerialTaskCoordinator()
    await coordinator.flush()
    await coordinator.flush()
  }

  @Test("run runs at its caller's priority")
  func runRunsAtCallersPriority() async {
    #expect(Task.currentPriority < .high)
    let coordinator = SerialTaskCoordinator()
    let recorder = PriorityRecorder()

    await Task(priority: .high) {
      await coordinator.run {
        await recorder.record(Task.currentPriority)
      }
    }
    .value

    #expect(await recorder.recorded == .high)
  }

  @Test("Operations enqueued before the coordinator is released still run")
  func runsQueuedOperationsAfterRelease() async {
    let recorder = Recorder()
    let gate = Gate()
    var coordinator: SerialTaskCoordinator? = SerialTaskCoordinator()

    coordinator?.enqueue {
      await gate.wait()
    }
    for id in 0..<5 {
      coordinator?.enqueue {
        await recorder.didStart(id)
        await recorder.didFinish(id)
      }
    }
    coordinator = nil
    await gate.open()

    for _ in 0..<1_000 where await recorder.finished.count < 5 {
      try? await Task.sleep(nanoseconds: 1_000_000)
    }
    #expect(await recorder.finished == Array(0..<5))
  }

  /// Holds operations until it's opened.
  private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
      if isOpen {
        return
      }
      await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
      isOpen = true
      let waiters = self.waiters
      self.waiters = []
      for waiter in waiters {
        waiter.resume()
      }
    }
  }
}
