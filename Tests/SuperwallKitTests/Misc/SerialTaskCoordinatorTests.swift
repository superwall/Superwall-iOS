//
//  SerialTaskCoordinatorTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 11/09/2026.
//

import Foundation
import Testing

@testable import SuperwallKit

extension SerialTaskCoordinator {
  /// Waits for everything enqueued so far to finish.
  fileprivate func drain() async {
    await withCheckedContinuation { continuation in
      enqueue {
        continuation.resume()
      }
    }
  }
}

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

    func didFinish() {
      runningAtOnce -= 1
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
    await coordinator.drain()

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
    await coordinator.drain()

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
    await coordinator.drain()

    coordinator.enqueue {
      await recorder.didStart(1)
      await recorder.didFinish()
    }
    await coordinator.drain()

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
    await coordinator.drain()

    let recorded = await recorder.recorded
    #expect(recorded == .high)
  }
}
