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
    let coordinator = SerialTaskCoordinator(label: "test")
    let recorder = Recorder()

    for id in 0..<20 {
      coordinator.enqueue {
        await recorder.didStart(id)
        await Task.yield()
        await recorder.didFinish()
      }
    }
    await coordinator.lastTask?.value

    let order = await recorder.order
    let maxRunningAtOnce = await recorder.maxRunningAtOnce
    #expect(order == Array(0..<20))
    #expect(maxRunningAtOnce == 1)
  }

  @Test("Only one operation runs at a time when enqueued from many threads")
  func runsOneOperationAtATimeAcrossThreads() async {
    let coordinator = SerialTaskCoordinator(label: "test")
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
    await coordinator.lastTask?.value

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
    let coordinator = SerialTaskCoordinator(label: "test")
    let recorder = Recorder()

    coordinator.enqueue {
      await recorder.didStart(0)
      await recorder.didFinish()
    }
    await coordinator.lastTask?.value

    coordinator.enqueue {
      await recorder.didStart(1)
      await recorder.didFinish()
    }
    await coordinator.lastTask?.value

    let order = await recorder.order
    #expect(order == [0, 1])
  }
}
