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

/// Applies `updates` in order to an empty state.
private func state(_ updates: PaywallViewControllerCacheUpdate...) -> PaywallViewControllerCacheState {
  updates.reduce(PaywallViewControllerCacheState()) { $1.reduce($0) }
}

@Suite("PaywallViewControllerCacheUpdate reducers")
struct PaywallViewControllerCacheUpdateTests {
  @Test("saved adds or replaces the controller under a key")
  @MainActor
  func saved() {
    let dependencyContainer = DependencyContainer()
    let first = makeController(dependencyContainer)
    let second = makeController(dependencyContainer)

    let added = state(.saved(first, key: "a"))
    #expect(added.controllers["a"] === first)
    #expect(added.presentedKey == nil)

    let replaced = PaywallViewControllerCacheUpdate.saved(second, key: "a").reduce(added)
    #expect(replaced.controllers["a"] === second)
    #expect(replaced.controllers.count == 1)
  }

  @Test("saved over the controller on screen means nothing cached is on screen")
  @MainActor
  func savedOverPresented() {
    let dependencyContainer = DependencyContainer()
    let onScreen = makeController(dependencyContainer)
    let replacement = makeController(dependencyContainer)

    let result = state(.saved(onScreen, key: "a"), .presented(key: "a"), .saved(replacement, key: "a"))

    #expect(result.controllers["a"] === replacement)
    #expect(result.presentedKey == nil)
    #expect(result.presentedController == nil)
  }

  @Test("saved again with the controller on screen keeps it on screen")
  @MainActor
  func savedSameOverPresented() {
    let dependencyContainer = DependencyContainer()
    let onScreen = makeController(dependencyContainer)

    let result = state(.saved(onScreen, key: "a"), .presented(key: "a"), .saved(onScreen, key: "a"))

    #expect(result.presentedController === onScreen)
  }

  @Test("saved under another key leaves the controller on screen alone")
  @MainActor
  func savedOtherKey() {
    let dependencyContainer = DependencyContainer()
    let onScreen = makeController(dependencyContainer)

    let result = state(
      .saved(onScreen, key: "a"),
      .presented(key: "a"),
      .saved(makeController(dependencyContainer), key: "b")
    )

    #expect(result.presentedController === onScreen)
    #expect(result.controllers.count == 2)
  }

  @Test("removed drops only the given keys")
  @MainActor
  func removed() {
    let dependencyContainer = DependencyContainer()
    let controller = makeController(dependencyContainer)

    let result = state(
      .saved(controller, key: "a"),
      .saved(controller, key: "b"),
      .saved(controller, key: "c"),
      .removed(keys: ["a", "b", "missing"])
    )

    #expect(Set(result.controllers.keys) == ["c"])
  }

  @Test("removed with the controller on screen means nothing cached is on screen")
  @MainActor
  func removedPresented() {
    let dependencyContainer = DependencyContainer()

    let result = state(
      .saved(makeController(dependencyContainer), key: "a"),
      .presented(key: "a"),
      .removed(keys: ["a"])
    )

    #expect(result.presentedKey == nil)
    #expect(result.controllers.isEmpty)
  }

  @Test("removed under other keys leaves the controller on screen alone")
  @MainActor
  func removedOthers() {
    let dependencyContainer = DependencyContainer()
    let onScreen = makeController(dependencyContainer)

    let result = state(
      .saved(onScreen, key: "a"),
      .saved(makeController(dependencyContainer), key: "b"),
      .presented(key: "a"),
      .removed(keys: ["b"])
    )

    #expect(result.presentedController === onScreen)
  }

  @Test("presented marks a cached controller as on screen")
  @MainActor
  func presented() {
    let dependencyContainer = DependencyContainer()
    let controller = makeController(dependencyContainer)

    let result = state(.saved(controller, key: "a"), .presented(key: "a"))

    #expect(result.presentedKey == "a")
    #expect(result.presentedController === controller)
  }

  @Test("presented with a key that isn't cached means nothing cached is on screen")
  @MainActor
  func presentedUncached() {
    let dependencyContainer = DependencyContainer()

    #expect(state(.presented(key: "a")).presentedKey == nil)

    let replacingPrevious = state(
      .saved(makeController(dependencyContainer), key: "a"),
      .presented(key: "a"),
      .presented(key: "missing")
    )
    #expect(replacingPrevious.presentedKey == nil)
  }

  @Test("presented moves from one cached controller to another")
  @MainActor
  func presentedAnother() {
    let dependencyContainer = DependencyContainer()
    let second = makeController(dependencyContainer)

    let result = state(
      .saved(makeController(dependencyContainer), key: "a"),
      .saved(second, key: "b"),
      .presented(key: "a"),
      .presented(key: "b")
    )

    #expect(result.presentedController === second)
  }

  @Test("dismissed clears the controller on screen and keeps it cached")
  @MainActor
  func dismissed() {
    let dependencyContainer = DependencyContainer()
    let controller = makeController(dependencyContainer)

    let result = state(.saved(controller, key: "a"), .presented(key: "a"), .dismissed)

    #expect(result.presentedKey == nil)
    #expect(result.controllers["a"] === controller)
    #expect(state(.dismissed).presentedKey == nil)
  }
}

@Suite("PaywallViewControllerCacheAction")
struct PaywallViewControllerCacheActionTests {
  @Test("removeAllExceptPresented keeps the paywall on screen and releases the rest")
  @MainActor
  func removeAllExceptPresented() {
    let dependencyContainer = DependencyContainer()
    let active = makeController(dependencyContainer)
    let other = makeController(dependencyContainer)
    let context = FakeCacheContext()
    context.dispatch(.save(active, key: "active"))
    context.dispatch(.save(other, key: "other"))
    context.dispatch(.presented(key: "active"))

    context.dispatch(.removeAllExceptPresented)

    #expect(Set(context.store.state.controllers.keys) == ["active"])
    #expect(context.store.state.presentedController === active)
    #expect(context.released.count == 1)
    #expect(context.released.first?.count == 1)
    #expect(context.released.first?.first === other)
  }

  @Test("removeAllExceptPresented with nothing on screen removes everything")
  @MainActor
  func removeAllWithNothingPresented() {
    let dependencyContainer = DependencyContainer()
    let context = FakeCacheContext()
    context.dispatch(.save(makeController(dependencyContainer), key: "a"))
    context.dispatch(.save(makeController(dependencyContainer), key: "b"))

    context.dispatch(.removeAllExceptPresented)

    #expect(context.store.state.controllers.isEmpty)
    #expect(context.released.first?.count == 2)
  }

  @Test("removeAllExceptPresented after a dismissal removes the dismissed paywall too")
  @MainActor
  func removeAllAfterDismissal() {
    let dependencyContainer = DependencyContainer()
    let context = FakeCacheContext()
    context.dispatch(.save(makeController(dependencyContainer), key: "a"))
    context.dispatch(.presented(key: "a"))
    context.dispatch(.dismissed)

    context.dispatch(.removeAllExceptPresented)

    #expect(context.store.state.controllers.isEmpty)
    #expect(context.released.first?.count == 1)
  }

  @Test("removing the paywall on screen releases it, and a later reset removes what's saved under its key")
  @MainActor
  func removePresented() {
    let dependencyContainer = DependencyContainer()
    let onScreen = makeController(dependencyContainer)
    let later = makeController(dependencyContainer)
    let context = FakeCacheContext()
    context.dispatch(.save(onScreen, key: "a"))
    context.dispatch(.presented(key: "a"))

    context.dispatch(.remove(key: "a"))
    #expect(context.store.state.presentedKey == nil)
    #expect(context.released.first?.first === onScreen)

    context.dispatch(.save(later, key: "a"))
    context.dispatch(.removeAllExceptPresented)

    #expect(context.store.state.controllers.isEmpty)
    #expect(context.released.last?.first === later)
  }

  @Test("saving over the paywall on screen releases it, and a later reset removes the replacement")
  @MainActor
  func saveOverPresented() {
    let dependencyContainer = DependencyContainer()
    let onScreen = makeController(dependencyContainer)
    let replacement = makeController(dependencyContainer)
    let context = FakeCacheContext()
    context.dispatch(.save(onScreen, key: "a"))
    context.dispatch(.presented(key: "a"))

    context.dispatch(.save(replacement, key: "a"))
    #expect(context.store.state.presentedKey == nil)
    #expect(context.released.first?.first === onScreen)

    context.dispatch(.removeAllExceptPresented)
    #expect(context.store.state.controllers.isEmpty)
    #expect(context.released.last?.first === replacement)
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

  @Test("presented and dismissed release nothing")
  @MainActor
  func presentAndDismiss() {
    let dependencyContainer = DependencyContainer()
    let controller = makeController(dependencyContainer)
    let context = FakeCacheContext()
    context.dispatch(.save(controller, key: "a"))

    context.dispatch(.presented(key: "a"))
    #expect(context.store.state.presentedController === controller)
    context.dispatch(.presented(key: "missing"))
    #expect(context.store.state.presentedKey == nil)
    context.dispatch(.presented(key: "a"))
    context.dispatch(.dismissed)
    #expect(context.store.state.presentedKey == nil)

    #expect(context.released.isEmpty)
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
    context.dispatch(.removeAllExceptPresented)

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

    await withTaskGroup(of: Void.self) { group in
      for index in 0..<200 {
        group.addTask {
          cache.save(controller, forKey: "key-\(index)")
        }
      }
    }
    #expect(cache.store.state.controllers.count == 200)
    cache.activePaywallVcKey = "key-0"

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
  @MainActor
  func concurrentActiveKeys() async {
    let dependencyContainer = DependencyContainer()
    let cache = PaywallViewControllerCache(deviceLocaleString: "en")
    let controller = makeController(dependencyContainer, cache: cache)
    for index in 0..<200 {
      cache.save(controller, forKey: "key-\(index)")
    }
    let seen = Box<[(before: String?, after: String?)]>([])
    cache.store.observe { before, after in
      seen.value.append((before.presentedKey, after.presentedKey))
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

  @Test("reading the cache on another thread never lets a removed controller go off the main thread")
  @MainActor
  func readsDontOutliveRemovals() async {
    let dependencyContainer = DependencyContainer()
    let cache = PaywallViewControllerCache(deviceLocaleString: "en")
    let active = makeController(dependencyContainer, cache: cache)
    cache.save(active, forKey: "active")
    cache.activePaywallVcKey = "active"
    let offMainReleases = Box(0)
    let lock = NSLock()
    let stop = Box(false)

    let readers = (0..<4).map { _ in
      Thread {
        while !lock.withLock({ stop.value }) {
          _ = cache.activePaywallViewController
          _ = cache.getPaywallViewController(forKey: "active")
          _ = cache.activePaywallVcKey
        }
      }
    }
    readers.forEach { $0.start() }

    for _ in 0..<60 {
      let controller = makeController(dependencyContainer, cache: cache)
      objc_setAssociatedObject(
        controller,
        &releaseSentinelKey,
        ReleaseSentinel {
          if !Thread.isMainThread {
            lock.withLock { offMainReleases.value += 1 }
          }
        },
        .OBJC_ASSOCIATION_RETAIN
      )
      cache.save(controller, forKey: "victim")
      cache.removePaywallViewController(forKey: "victim")
    }

    lock.withLock { stop.value = true }
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { continuation.resume() }
    }
    #expect(lock.withLock { offMainReleases.value } == 0)
  }

  @Test("a controller saved under the key of a removed paywall on screen isn't kept by a reset")
  @MainActor
  func removedActiveKeyDoesNotDangle() {
    let dependencyContainer = DependencyContainer()
    let cache = PaywallViewControllerCache(deviceLocaleString: "en")
    cache.save(makeController(dependencyContainer, cache: cache), forKey: "a")
    cache.activePaywallVcKey = "a"

    cache.removePaywallViewController(forKey: "a")
    #expect(cache.activePaywallVcKey == nil)

    let replacement = makeController(dependencyContainer, cache: cache)
    cache.save(replacement, forKey: "a")
    #expect(cache.activePaywallViewController == nil)

    cache.removeAll()
    #expect(cache.getPaywallViewController(forKey: "a") == nil)
  }

  @Test("a paywall marked on screen before it's cached doesn't keep a later save through a reset")
  @MainActor
  func uncachedActiveKeyDoesNotDangle() {
    let dependencyContainer = DependencyContainer()
    let cache = PaywallViewControllerCache(deviceLocaleString: "en")
    cache.activePaywallVcKey = "a"
    #expect(cache.activePaywallVcKey == nil)

    cache.save(makeController(dependencyContainer, cache: cache), forKey: "a")
    #expect(cache.activePaywallViewController == nil)

    cache.removeAll()
    #expect(cache.getPaywallViewController(forKey: "a") == nil)
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

nonisolated(unsafe) private var releaseSentinelKey: UInt8 = 0

/// Runs `onRelease` when it's let go of, on the thread that lets it go.
private final class ReleaseSentinel {
  let onRelease: () -> Void
  init(_ onRelease: @escaping () -> Void) {
    self.onRelease = onRelease
  }
  deinit {
    onRelease()
  }
}

private final class Box<Value>: @unchecked Sendable {
  var value: Value
  init(_ value: Value) {
    self.value = value
  }
}
