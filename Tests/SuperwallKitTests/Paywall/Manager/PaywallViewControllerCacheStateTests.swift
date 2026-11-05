//
//  PaywallViewControllerCacheStateTests.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

@MainActor
private func makeController(
  _ dependencyContainer: DependencyContainer,
  cache: PaywallViewControllerCache? = nil
) -> PaywallViewController {
  dependencyContainer.makePaywallViewController(
    for: .stub(),
    withCache: cache,
    withPaywallArchiveManager: nil,
    delegate: nil
  )
}

/// Records what the cache's actions release, and whether another thread
/// could read the store while they did.
private final class FakeCacheContext: PaywallViewControllerCacheContext, @unchecked Sendable {
  let store = PaywallViewControllerCacheStore(initial: PaywallViewControllerCacheState())
  private(set) var released: [[PaywallViewController]] = []
  private(set) var storeWasReadableDuringRelease: [Bool] = []

  func release(_ released: ReleasedControllers) {
    self.released.append(released.controllers)
    let didRead = DispatchSemaphore(value: 0)
    let store = self.store
    Thread {
      _ = store.state
      didRead.signal()
    }.start()
    storeWasReadableDuringRelease.append(didRead.wait(timeout: .now() + 2) == .success)
    released.empty()
  }

  func dispatch(_ action: PaywallViewControllerCacheAction) {
    store.dispatch(action, in: self)
  }
}

@Suite("PaywallViewControllerCacheUpdate reducers")
struct PaywallViewControllerCacheUpdateTests {
  @Test("save adds or replaces the controller under a key")
  @MainActor
  func save() {
    let dependencyContainer = DependencyContainer()
    let first = makeController(dependencyContainer)
    let second = makeController(dependencyContainer)

    var state = PaywallViewControllerCacheUpdate.save(first, key: "a")
      .reduce(PaywallViewControllerCacheState())
    #expect(state.controllers["a"] === first)

    state = PaywallViewControllerCacheUpdate.save(second, key: "a").reduce(state)
    #expect(state.controllers["a"] === second)
    #expect(state.controllers.count == 1)
  }

  @Test("remove drops only the given keys and leaves the active key")
  @MainActor
  func remove() {
    let dependencyContainer = DependencyContainer()
    let controller = makeController(dependencyContainer)
    var state = PaywallViewControllerCacheState()
    state.controllers = ["a": controller, "b": controller, "c": controller]
    state.activeKey = "a"

    state = PaywallViewControllerCacheUpdate.remove(keys: ["a", "b", "missing"]).reduce(state)

    #expect(Set(state.controllers.keys) == ["c"])
    #expect(state.activeKey == "a")
    #expect(state.activeController == nil)
  }

  @Test("activeKey picks the active controller")
  @MainActor
  func activeKey() {
    let dependencyContainer = DependencyContainer()
    let controller = makeController(dependencyContainer)
    var state = PaywallViewControllerCacheState()
    state.controllers["a"] = controller
    #expect(state.activeController == nil)

    state = PaywallViewControllerCacheUpdate.activeKey("a").reduce(state)
    #expect(state.activeController === controller)

    state = PaywallViewControllerCacheUpdate.activeKey(nil).reduce(state)
    #expect(state.activeKey == nil)
    #expect(state.activeController == nil)
    #expect(state.controllers["a"] === controller)
  }
}

@Suite("PaywallViewControllerCacheAction")
struct PaywallViewControllerCacheActionTests {
  @Test("removeAllExceptActive keeps the paywall on screen and releases the rest")
  @MainActor
  func removeAllExceptActive() {
    let dependencyContainer = DependencyContainer()
    let active = makeController(dependencyContainer)
    let other = makeController(dependencyContainer)
    let context = FakeCacheContext()
    context.dispatch(.save(active, key: "active"))
    context.dispatch(.save(other, key: "other"))
    context.store.update(PaywallViewControllerCacheUpdate.activeKey("active"))

    context.dispatch(.removeAllExceptActive)

    #expect(Set(context.store.state.controllers.keys) == ["active"])
    #expect(context.store.state.activeController === active)
    #expect(context.released.count == 1)
    #expect(context.released.first?.count == 1)
    #expect(context.released.first?.first === other)
  }

  @Test("removeAllExceptActive with nothing on screen removes everything")
  @MainActor
  func removeAllWithNothingActive() {
    let dependencyContainer = DependencyContainer()
    let context = FakeCacheContext()
    context.dispatch(.save(makeController(dependencyContainer), key: "a"))
    context.dispatch(.save(makeController(dependencyContainer), key: "b"))

    context.dispatch(.removeAllExceptActive)

    #expect(context.store.state.controllers.isEmpty)
    #expect(context.released.first?.count == 2)
  }

  @Test("saving over a controller releases the old one, saving it again releases nothing")
  @MainActor
  func saveReplaces() {
    let dependencyContainer = DependencyContainer()
    let old = makeController(dependencyContainer)
    let new = makeController(dependencyContainer)
    let context = FakeCacheContext()

    context.dispatch(.save(old, key: "a"))
    context.dispatch(.save(old, key: "a"))
    #expect(context.released.isEmpty)

    context.dispatch(.save(new, key: "a"))
    #expect(context.store.state.controllers["a"] === new)
    #expect(context.released.count == 1)
    #expect(context.released.first?.first === old)
  }

  @Test("removing a missing key releases nothing")
  func removeMissing() {
    let context = FakeCacheContext()
    context.dispatch(.remove(key: "missing"))
    #expect(context.released.isEmpty)
  }

  @Test("released controllers are let go of with the store unlocked")
  @MainActor
  func releaseIsUnlocked() {
    let dependencyContainer = DependencyContainer()
    let context = FakeCacheContext()
    context.dispatch(.save(makeController(dependencyContainer), key: "a"))
    context.dispatch(.save(makeController(dependencyContainer), key: "b"))

    context.dispatch(.remove(key: "a"))
    context.dispatch(.removeAllExceptActive)

    #expect(context.storeWasReadableDuringRelease == [true, true])
  }
}

@Suite("PaywallViewControllerCache")
struct PaywallViewControllerCacheStoreTests {
  @Test("a controller dropped off the main thread is let go of on the main thread")
  @MainActor
  func releasesOnMain() async {
    let dependencyContainer = DependencyContainer()
    let cache = PaywallViewControllerCache(deviceLocaleString: "en")
    weak var weakController: PaywallViewController?
    do {
      let controller = makeController(dependencyContainer, cache: cache)
      weakController = controller
      cache.save(controller, forKey: "a")
    }
    #expect(weakController != nil)

    // Main is blocked until the background removal has returned, so the
    // controller can only be let go of once main runs again.
    let removed = DispatchSemaphore(value: 0)
    let heldAfterRemoval = Box(false)
    Thread {
      cache.removePaywallViewController(forKey: "a")
      heldAfterRemoval.value = weakController != nil
      removed.signal()
    }.start()
    removed.wait()

    #expect(cache.getPaywallViewController(forKey: "a") == nil)
    #expect(heldAfterRemoval.value)

    await Task.yield()
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { continuation.resume() }
    }
    #expect(weakController == nil)
  }

  @Test("200 concurrent saves and removes all land, and leave the active paywall")
  @MainActor
  func concurrentChanges() async {
    let dependencyContainer = DependencyContainer()
    let cache = PaywallViewControllerCache(deviceLocaleString: "en")
    let controller = makeController(dependencyContainer, cache: cache)
    cache.activePaywallVcKey = "key-0"

    await withTaskGroup(of: Void.self) { group in
      for index in 0..<200 {
        group.addTask {
          cache.save(controller, forKey: "key-\(index)")
        }
      }
    }
    #expect(cache.store.state.controllers.count == 200)

    await withTaskGroup(of: Void.self) { group in
      for index in 0..<200 where index.isMultiple(of: 2) {
        group.addTask {
          cache.removePaywallViewController(forKey: "key-\(index + 1)")
        }
      }
      for _ in 0..<10 {
        group.addTask {
          cache.removeAll()
        }
      }
    }

    #expect(Set(cache.store.state.controllers.keys) == ["key-0"])
    #expect(cache.activePaywallViewController === controller)
  }

  @Test("200 concurrent active key changes are applied one at a time")
  func concurrentActiveKeys() async {
    let cache = PaywallViewControllerCache(deviceLocaleString: "en")
    let seen = Box<[(before: String?, after: String?)]>([])
    cache.store.observe { before, after in
      seen.value.append((before.activeKey, after.activeKey))
    }

    await withTaskGroup(of: Void.self) { group in
      for index in 0..<200 {
        group.addTask {
          cache.activePaywallVcKey = "key-\(index)"
        }
      }
    }

    #expect(seen.value.count == 200)
    for (previous, next) in zip(seen.value, seen.value.dropFirst()) {
      #expect(previous.after == next.before)
    }
    #expect(seen.value.last?.after == cache.activePaywallVcKey)
    #expect(Set(seen.value.compactMap(\.after)).count == 200)
  }

  @Test("resetting the cache keeps the paywall on screen")
  @MainActor
  func resetKeepsActive() {
    let dependencyContainer = DependencyContainer()
    let cache = PaywallViewControllerCache(deviceLocaleString: "en")
    let active = makeController(dependencyContainer, cache: cache)
    let other = makeController(dependencyContainer, cache: cache)
    cache.save(active, forKey: "active")
    cache.save(other, forKey: "other")
    cache.activePaywallVcKey = "active"

    cache.removeAll()

    #expect(cache.getPaywallViewController(forKey: "active") === active)
    #expect(cache.getPaywallViewController(forKey: "other") == nil)
    #expect(cache.activePaywallViewController === active)
  }
}

private final class Box<Value>: @unchecked Sendable {
  var value: Value
  init(_ value: Value) {
    self.value = value
  }
}
