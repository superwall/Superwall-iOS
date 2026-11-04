//
//  IdentityActionTests.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Holds a task at a known point until the test opens it.
private final class Latch: @unchecked Sendable {
  private let lock = NSLock()
  private var opened = false
  private var waiting: [CheckedContinuation<Void, Never>] = []

  func wait() async {
    await withCheckedContinuation { continuation in
      lock.lock()
      if opened {
        lock.unlock()
        continuation.resume()
        return
      }
      waiting.append(continuation)
      lock.unlock()
    }
  }

  func open() {
    lock.lock()
    opened = true
    let waiting = self.waiting
    self.waiting = []
    lock.unlock()
    waiting.forEach { $0.resume() }
  }
}

/// Records what the actions ask of their context, and lets tests hold the
/// config and assignments open.
private final class FakeIdentityContext: IdentityContext, @unchecked Sendable {
  let store: IdentityStore
  var seeds: [String: Int] = [:]
  var configLatch: Latch?
  var assignmentsLatch: Latch?
  /// One latch per assignments fetch, used in call order. Takes precedence
  /// over `assignmentsLatch`.
  var assignmentsLatches: [Latch] = []
  /// Whether the identity counted as ready while the reset for a new user ran.
  private(set) var wasReadyDuringReset: Bool?
  /// Attributes the reset for a new user merges, as the SDK re-applies
  /// install-scoped attribution.
  var attributesMergedOnReset: [String: Any?]?

  private let lock = NSLock()
  private var _events: [String] = []
  private var _tracked: [[String: Any]] = []
  private var _notified: [[String: Any]] = []
  private var _persisted: [IdentityState] = []
  private var _readiness: [Bool] = []
  private var sideEffects: [Task<Void, Never>] = []

  var events: [String] { locked { _events } }
  var tracked: [[String: Any]] { locked { _tracked } }
  var notified: [[String: Any]] { locked { _notified } }
  var persisted: [IdentityState] { locked { _persisted } }
  var readiness: [Bool] { locked { _readiness } }

  init(_ state: IdentityState) {
    store = IdentityStore(initial: state)
    IdentityInterceptors.installObservers(
      on: store,
      persist: { _, _ in },
      readinessChanged: { [unowned self] ready in
        locked { _readiness.append(ready) }
      }
    )
  }

  private func locked<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }

  private func record(_ event: String) {
    locked { _events.append(event) }
  }

  /// Waits for every side effect and every queued action, including the
  /// ones they start.
  func settle() async {
    while true {
      await store.flush()
      let pending: [Task<Void, Never>] = locked {
        let tasks = sideEffects
        sideEffects = []
        return tasks
      }
      if pending.isEmpty {
        return
      }
      for task in pending {
        await task.value
      }
    }
  }

  func userIdSeed(for userId: String) async -> Int? {
    await configLatch?.wait()
    return seeds[userId]
  }

  func fetchAssignments() async {
    record("fetchAssignments")
    let latch: Latch? = locked {
      assignmentsLatches.isEmpty ? assignmentsLatch : assignmentsLatches.removeFirst()
    }
    await latch?.wait()
  }

  func redeemExistingWebEntitlements() async {
    record("redeem")
  }

  func resetForNewUser() {
    record("resetForNewUser")
    // What `Superwall.reset(duringIdentify: true)` does to this store.
    store.update(IdentityUpdate.reset(aliasId: "$SuperwallAlias:after-reset", seed: 5))
    wasReadyDuringReset = store.state.isReady
    if let attributes = attributesMergedOnReset {
      dispatch(.mergeAttributes(attributes, shouldTrack: false, shouldNotify: false))
    }
  }

  func trackIdentityAlias() {
    record("trackIdentityAlias")
  }

  func trackUserAttributes(_ attributes: [String: Any]) {
    locked { _tracked.append(attributes) }
  }

  func notifyUserChange(_ attributes: [String: Any]) {
    locked { _notified.append(attributes) }
  }

  func persistIdentity(_ state: IdentityState) {
    locked { _persisted.append(state) }
  }

  func sideEffect(_ work: @escaping () async -> Void) {
    let task = Task { await work() }
    locked { sideEffects.append(task) }
  }
}

private func readyState(
  appUserId: String? = nil,
  userAttributes: [String: Any] = [:]
) -> IdentityState {
  IdentityState(
    appUserId: appUserId,
    aliasId: "$SuperwallAlias:alias-1",
    seed: 42,
    userAttributes: userAttributes,
    pending: [],
    hasResolved: true,
    appInstalledAtString: "2026-01-01"
  )
}

@Suite("Identity actions")
struct IdentityActionTests {
  // MARK: - identify

  @Test("identify logs in, saves everything, tracks, and fetches assignments")
  func identifyAnonymousUser() async {
    let context = FakeIdentityContext(readyState())

    context.dispatch(.identify(userId: "user-1", restoreAssignments: false))
    // Applied before dispatch returns. The seed is still pending.
    #expect(context.state.appUserId == "user-1")
    #expect(context.state.pending == [.seed("user-1")])
    await context.settle()

    let state = context.state
    #expect(state.appUserId == "user-1")
    #expect(state.aliasId == "$SuperwallAlias:alias-1")
    #expect(state.isReady)
    #expect(context.events.contains("resetForNewUser") == false)
    #expect(context.events.contains("trackIdentityAlias"))
    #expect(context.events.contains("fetchAssignments"))
    #expect(context.events.contains("redeem"))
    #expect(context.persisted.last?.appUserId == "user-1")
    #expect(context.tracked.first?["appUserId"] as? String == "user-1")
    #expect(context.readiness == [false, true])
  }

  @Test("identifying the current user again does nothing and doesn't flicker readiness")
  func identifySameUser() async {
    let context = FakeIdentityContext(readyState(appUserId: "user-1"))

    context.dispatch(.identify(userId: "user-1", restoreAssignments: false))
    #expect(context.state.isReady)
    await context.settle()

    #expect(context.events.isEmpty)
    #expect(context.persisted.isEmpty)
    #expect(context.readiness.isEmpty)
  }

  @Test("identifying another user resets before setting the new user")
  func identifySwitchesUser() async {
    let context = FakeIdentityContext(
      readyState(appUserId: "user-1", userAttributes: ["only_for_user_1": true])
    )

    context.dispatch(.identify(userId: "user-2", restoreAssignments: false))
    await context.settle()

    let state = context.state
    #expect(context.events.first == "resetForNewUser")
    #expect(state.appUserId == "user-2")
    #expect(state.aliasId == "$SuperwallAlias:after-reset")
    #expect(state.userAttributes["only_for_user_1"] == nil)
    #expect(state.userAttributes["appUserId"] as? String == "user-2")
    // Saved in full after the reset, which may have wiped storage.
    #expect(context.persisted.last?.aliasId == "$SuperwallAlias:after-reset")
    #expect(context.persisted.last?.appUserId == "user-2")
  }

  @Test("Attributes the switch's reset merges land on the new user before identify returns")
  func resetMergesLandOnNewUser() async {
    let context = FakeIdentityContext(readyState(appUserId: "user-1"))
    context.attributesMergedOnReset = ["acquisition_source": "network"]

    context.dispatch(.identify(userId: "user-2", restoreAssignments: false))

    #expect(context.state.appUserId == "user-2")
    #expect(context.state.userAttributes["acquisition_source"] as? String == "network")
    await context.settle()
  }

  @Test("A user switch isn't ready while it resets, before the new id is set")
  func switchIsNotReadyDuringReset() async {
    let context = FakeIdentityContext(readyState(appUserId: "user-1"))

    context.dispatch(.identify(userId: "user-2", restoreAssignments: false))

    #expect(context.wasReadyDuringReset == false)
    await context.settle()
    #expect(context.state.isReady)
  }

  @Test("Restoring an earlier user's assignments doesn't make the next user ready")
  func staleAssignmentsDontMakeNextUserReady() async throws {
    let context = FakeIdentityContext(readyState())
    let first = Latch()
    let second = Latch()
    context.assignmentsLatches = [first, second]

    context.dispatch(.identify(userId: "user-1", restoreAssignments: true))
    // So that user-1's fetch takes the first latch.
    while !context.events.contains("fetchAssignments") {
      try await Task.sleep(nanoseconds: 1_000_000)
    }
    context.dispatch(.identify(userId: "user-2", restoreAssignments: true))
    first.open()
    try await context.store.waitUntil { !$0.pending.contains(.assignments("user-1")) }

    #expect(context.state.pending.contains(.assignments("user-2")))
    #expect(context.state.isReady == false)

    second.open()
    await context.settle()
    #expect(context.state.isReady)
  }

  @Test("identify waits for assignments only when restoring them")
  func identifyRestoringAssignments() async {
    let context = FakeIdentityContext(readyState())
    let assignments = Latch()
    context.assignmentsLatch = assignments

    context.dispatch(.identify(userId: "user-1", restoreAssignments: true))
    await context.store.flush()
    #expect(context.state.pending.contains(.assignments("user-1")))
    #expect(context.state.isReady == false)

    assignments.open()
    await context.settle()
    #expect(context.state.isReady)
  }

  @Test("identify doesn't wait for assignments by default")
  func identifyWithoutRestoringAssignments() async {
    let context = FakeIdentityContext(readyState())
    let assignments = Latch()
    context.assignmentsLatch = assignments

    context.dispatch(.identify(userId: "user-1", restoreAssignments: false))
    // Only the seed is outstanding: no config latch, so it resolves at once.
    let ready = try? await context.store.waitUntil { $0.isReady }
    #expect(ready != nil)
    #expect(context.state.pending.isEmpty)
    assignments.open()
    await context.settle()
  }

  // MARK: - Seed

  @Test("The seed comes from the user id once the config allows it")
  func seedFromConfig() async {
    let context = FakeIdentityContext(readyState())
    context.seeds["user-1"] = 7
    let config = Latch()
    context.configLatch = config

    context.dispatch(.identify(userId: "user-1", restoreAssignments: false))
    await context.store.flush()
    #expect(context.state.pending == [.seed("user-1")])
    #expect(context.state.seed == 42)

    config.open()
    await context.settle()
    #expect(context.state.seed == 7)
    #expect(context.state.userAttributes["seed"] as? Int == 7)
    #expect(context.state.isReady)
    #expect(context.tracked.last?["seed"] as? Int == 7)
  }

  @Test("Waiting for the config doesn't hold up later changes")
  func mergeIsNotBlockedBySeed() async {
    let context = FakeIdentityContext(readyState())
    let config = Latch()
    context.configLatch = config

    context.dispatch(.identify(userId: "user-1", restoreAssignments: false))
    context.dispatch(.mergeAttributes(["plan": "pro"], shouldTrack: false, shouldNotify: false))
    await context.store.flush()

    #expect(context.state.userAttributes["plan"] as? String == "pro")
    #expect(context.state.isReady == false)

    config.open()
    await context.settle()
    #expect(context.state.isReady)
  }

  @Test("A seed that arrives after a user switch doesn't apply to the new user")
  func staleSeedIsIgnored() async {
    let context = FakeIdentityContext(readyState())
    context.seeds["user-1"] = 7
    context.seeds["user-2"] = 9
    let config = Latch()
    context.configLatch = config

    context.dispatch(.identify(userId: "user-1", restoreAssignments: false))
    context.dispatch(.identify(userId: "user-2", restoreAssignments: false))
    await context.store.flush()
    config.open()
    await context.settle()

    #expect(context.state.appUserId == "user-2")
    #expect(context.state.seed == 9)
    #expect(context.state.isReady)
  }

  @Test("A reset while the seed is pending doesn't leave the identity stuck")
  func resetDuringPendingSeed() async {
    let context = FakeIdentityContext(readyState())
    context.seeds["user-1"] = 7
    let config = Latch()
    context.configLatch = config

    context.dispatch(.identify(userId: "user-1", restoreAssignments: false))
    context.dispatch(.reset)
    await context.store.flush()
    #expect(context.state.appUserId == nil)
    #expect(context.state.isReady == false)

    config.open()
    await context.settle()
    #expect(context.state.isReady)
    #expect(context.state.seed != 7)
  }

  // MARK: - Attributes

  @Test("Merges land on the user identified before them, in order")
  func mergesFollowIdentify() async {
    let context = FakeIdentityContext(readyState(appUserId: "user-1"))

    context.dispatch(.mergeAttributes(["a": 1], shouldTrack: false, shouldNotify: false))
    context.dispatch(.identify(userId: "user-2", restoreAssignments: false))
    context.dispatch(.mergeAttributes(["b": 2], shouldTrack: true, shouldNotify: true))
    await context.settle()

    let attributes = context.state.userAttributes
    // `a` belonged to user-1 and went with the reset.
    #expect(attributes["a"] == nil)
    #expect(attributes["b"] as? Int == 2)
    #expect(context.notified.count == 1)
    #expect(context.notified.first?["appUserId"] as? String == "user-2")
    #expect(context.tracked.last?["b"] as? Int == 2)
  }

  @Test("Merges dispatched from many threads are all applied")
  func concurrentMerges() async {
    let context = FakeIdentityContext(readyState())
    await withTaskGroup(of: Void.self) { group in
      for index in 0..<200 {
        group.addTask {
          context.dispatch(.mergeAttributes(["key\(index)": index], shouldTrack: true, shouldNotify: false))
        }
      }
    }
    let attributes = context.state.userAttributes
    // `index` is typed explicitly: left to inference it becomes `Int?`, and
    // the key turns into "keyOptional(0)".
    let missing = (0..<200).filter { (index: Int) in attributes["key\(index)"] as? Int != index }
    #expect(missing.isEmpty, "missing \(missing)")
  }

  @Test("Merging without tracking or notifying does neither")
  func quietMerge() async {
    let context = FakeIdentityContext(readyState())
    context.dispatch(.mergeAttributes(["a": 1], shouldTrack: false, shouldNotify: false))
    await context.settle()
    #expect(context.tracked.isEmpty)
    #expect(context.notified.isEmpty)
    #expect(context.state.userAttributes["a"] as? Int == 1)
  }

  // MARK: - Reset

  @Test("reset gives the user a new anonymous identity straight away")
  func reset() async {
    let context = FakeIdentityContext(readyState(appUserId: "user-1", userAttributes: ["a": 1]))

    context.dispatch(.reset)
    #expect(context.state.appUserId == nil)
    await context.settle()

    let state = context.state
    #expect(state.appUserId == nil)
    #expect(state.aliasId != "$SuperwallAlias:alias-1")
    #expect(state.aliasId.hasPrefix(IdentityLogic.superwallPrefix))
    #expect(state.userAttributes["a"] == nil)
    #expect(state.userAttributes["aliasId"] as? String == state.aliasId)
    #expect(state.isReady)
    #expect(context.readiness.isEmpty)
  }

  @Test("persist saves the identity as it is once earlier changes have run")
  func persistRunsAfterEarlierChanges() async {
    let context = FakeIdentityContext(readyState(appUserId: "user-1"))
    context.dispatch(.reset)
    context.dispatch(.persist)
    await context.settle()
    #expect(context.persisted.last?.appUserId == nil)
    #expect(context.persisted.last?.aliasId == context.state.aliasId)
  }

  @Test("Debug descriptions leave out user ids and attribute values")
  func descriptionsHidePersonalData() {
    let identify = IdentityAction.identify(userId: "secret-user", restoreAssignments: true)
    let merge = IdentityAction.mergeAttributes(["email": "secret@example.com"], shouldTrack: true, shouldNotify: false)
    #expect(String(describing: identify).contains("secret") == false)
    #expect(String(describing: merge).contains("secret") == false)
    #expect(String(describing: merge).contains("email"))
  }
}
