//
//  RestoreStateTests.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

@Suite("RestoreUpdate reducers")
struct RestoreUpdateTests {
  @Test("begin counts a running restore and keeps its source")
  func begin() {
    let state = RestoreUpdate.begin(.external).reduce(RestoreState())
    #expect(state.running == 1)
    #expect(state.source == .external)
    #expect(state.isRestoring)
  }

  @Test("finish ends the restores one at a time, then clears the source")
  func finish() {
    var state = RestoreUpdate.begin(.external).reduce(RestoreState())
    state = RestoreUpdate.begin(.external).reduce(state)

    state = RestoreUpdate.finish.reduce(state)
    #expect(state.running == 1)
    #expect(state.source == .external)

    state = RestoreUpdate.finish.reduce(state)
    #expect(state.running == 0)
    #expect(state.source == nil)
    #expect(!state.isRestoring)
  }

  @Test("finish with nothing running stays idle")
  func finishWhenIdle() {
    let state = RestoreUpdate.finish.reduce(RestoreState())
    #expect(state.running == 0)
  }
}

@Suite("RestoreFlow")
struct RestoreFlowTests {
  @Test("200 concurrent restores that begin and finish leave it idle")
  func concurrentRestores() async {
    let store = RestoreStore(initial: RestoreState())
    let maxRunning = MaxCounter()
    store.observe { _, after in
      maxRunning.record(after.running)
    }
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<200 {
        group.addTask {
          store.update(RestoreUpdate.begin(.external))
          store.update(RestoreUpdate.finish)
        }
      }
    }
    #expect(store.state.running == 0)
    #expect(!store.state.isRestoring)
    #expect(maxRunning.value >= 1)
  }

  @Test("a restore is counted while it runs and not after")
  func restoreIsCounted() async {
    let controller = RecordingPurchaseController()
    let dependencyContainer = DependencyContainer(purchaseController: controller)
    let flow = RestoreFlow(
      purchaseController: controller,
      purchaseManager: dependencyContainer.purchaseManager,
      factory: dependencyContainer
    )
    flow.trackEvent = { _ in }
    let runningDuringRestore = MaxCounter()
    flow.restorePurchases = {
      runningDuringRestore.record(flow.store.state.running)
      return .restored
    }
    let observed = MaxCounter()
    flow.store.observe { _, after in
      observed.record(after.running)
    }

    _ = await flow.restore(.external, presentsFailureAlert: false)

    #expect(runningDuringRestore.value == 1)
    #expect(observed.value == 1)
    #expect(!flow.isRestoring)
    #expect(flow.store.state.source == nil)
  }
}

private final class RecordingPurchaseController: PurchaseController {
  func purchase(product: StoreProduct) async -> PurchaseResult {
    return .cancelled
  }

  func restorePurchases() async -> RestorationResult {
    return .restored
  }
}

private final class MaxCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var maximum = 0

  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return maximum
  }

  func record(_ value: Int) {
    lock.lock()
    maximum = max(maximum, value)
    lock.unlock()
  }
}
