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
  /// What `attributesKeptAcrossReset()` returns.
  var keptAttributes: [String: Any?] = [:]
  /// Runs inside `resetRestOfSDK()`.
  var onResetRestOfSDK: ((FakeIdentityContext) -> Void)?

  private let lock = NSLock()
  private var _events: [String] = []
  private var _tracked: [[String: Any]] = []
  private var _notified: [[String: Any]] = []
  private var _persisted: [IdentityState] = []
  private var _readiness: [Bool] = []
  private var _stateDuringReset: IdentityState?
  private var sideEffects: [Task<Void, Never>] = []

  var events: [String] { locked { _events } }
  var tracked: [[String: Any]] { locked { _tracked } }
  var notified: [[String: Any]] { locked { _notified } }
  var persisted: [IdentityState] { locked { _persisted } }
  var readiness: [Bool] { locked { _readiness } }
  /// The identity as `resetRestOfSDK()` found it.
  var stateDuringReset: IdentityState? { locked { _stateDuringReset } }

  init(_ state: IdentityState) {
    store = IdentityStore(initial: state)
    IdentityObservers.install(
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

  /// Hands over the side effects started so far, for a test to wait on.
  func takeSideEffects() -> [Task<Void, Never>] {
    locked {
      let tasks = sideEffects
      sideEffects = []
      return tasks
    }
  }

  /// Waits for every side effect, including the ones they start.
  func settle() async {
    while true {
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

  func attributesKeptAcrossReset() -> [String: Any?] {
    record("attributesKeptAcrossReset")
    return keptAttributes
  }

  func resetRestOfSDK() {
    record("resetRestOfSDK")
    let state = store.state
    locked { _stateDuringReset = state }
    onResetRestOfSDK?(self)
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
    record("persist")
    locked { _persisted.append(state) }
  }

  func sideEffect(_ work: @escaping () async -> Void) {
    let task = Task { await work() }
    locked { sideEffects.append(task) }
  }
}

extension IdentityState {
  /// Pending work by kind and user, for comparing without the ids an
  /// identify or reset makes up.
  var pendingSummary: [String] {
    pending.map { item in
      switch item {
      case .configuration:
        return "configuration"
      case .seed(let operation):
        return "seed:\(operation.userId)"
      case .assignments(let operation):
        return "assignments:\(operation.userId)"
      case .reset:
        return "reset"
      }
    }
    .sorted()
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

/// Polls `condition` until it holds or `timeout` passes.
private func eventually(
  timeout: TimeInterval = 3,
  _ condition: () -> Bool
) async -> Bool {
  let deadline = Date().addingTimeInterval(timeout)
  while Date() < deadline {
    if condition() {
      return true
    }
    try? await Task.sleep(nanoseconds: 1_000_000)
  }
  return condition()
}

private func identify(
  _ userId: String,
  restoreAssignments: Bool = false,
  keptAttributes: [String: Any?]? = nil
) -> IdentityAction {
  .identify(userId: userId, restoreAssignments: restoreAssignments, keptAttributes: keptAttributes)
}

@Suite("Identity actions")
struct IdentityActionTests {
  // MARK: - identify

  @Test("identify logs in, saves everything, tracks, and fetches assignments")
  func identifyAnonymousUser() async {
    let context = FakeIdentityContext(readyState())
    // Holds the seed lookup, which otherwise can finish before the checks
    // below run.
    let config = Latch()
    context.configLatch = config

    context.dispatch(identify("user-1"))
    // Applied before dispatch returns. The seed is still pending.
    #expect(context.state.appUserId == "user-1")
    #expect(context.state.pendingSummary == ["seed:user-1"])
    config.open()
    await context.settle()

    let state = context.state
    #expect(state.appUserId == "user-1")
    #expect(state.aliasId == "$SuperwallAlias:alias-1")
    #expect(state.isReady)
    #expect(context.events.contains("resetRestOfSDK") == false)
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

    context.dispatch(identify("user-1", keptAttributes: ["kept": 1]))
    #expect(context.state.isReady)
    await context.settle()

    #expect(context.events.isEmpty)
    #expect(context.persisted.isEmpty)
    #expect(context.readiness.isEmpty)
    #expect(context.state.userAttributes["kept"] == nil)
  }

  @Test("Identifying from anonymous keeps the user's attributes and resets nothing")
  func identifyFromAnonymousDoesNotReset() async {
    let context = FakeIdentityContext(readyState(userAttributes: ["plan": "pro"]))

    context.dispatch(identify("user-1", keptAttributes: ["kept": 1]))
    await context.settle()

    #expect(context.state.userAttributes["plan"] as? String == "pro")
    #expect(context.state.userAttributes["kept"] == nil)
    #expect(context.state.aliasId == "$SuperwallAlias:alias-1")
    #expect(context.events.contains("resetRestOfSDK") == false)
  }

  // MARK: - Switching user

  @Test("Identifying another user replaces the old one, keeping only the kept attributes")
  func identifySwitchesUser() async {
    let context = FakeIdentityContext(
      readyState(appUserId: "user-1", userAttributes: ["only_for_user_1": true])
    )

    context.dispatch(identify("user-2", keptAttributes: ["acquisition_source": "network"]))

    // All of it is there when dispatch returns.
    let state = context.state
    #expect(state.appUserId == "user-2")
    #expect(state.aliasId != "$SuperwallAlias:alias-1")
    #expect(state.aliasId.hasPrefix(IdentityLogic.superwallPrefix))
    #expect(state.userAttributes["only_for_user_1"] == nil)
    #expect(state.userAttributes["acquisition_source"] as? String == "network")
    #expect(state.userAttributes["appUserId"] as? String == "user-2")
    #expect(state.userAttributes["aliasId"] as? String == state.aliasId)
    // The attributes were gathered before, so they're not asked for again.
    #expect(context.events.contains("attributesKeptAcrossReset") == false)
    // One user_attributes event for the switch.
    #expect(context.tracked.count == 1)
    #expect(context.tracked.first?["acquisition_source"] as? String == "network")
    await context.settle()
  }

  @Test("The rest of the SDK resets after the switch, unlocked, before the identity is ready")
  func switchResetsRestOfSDK() async {
    let context = FakeIdentityContext(readyState(appUserId: "user-1"))
    // Holds the seed, so it's still pending below.
    let config = Latch()
    context.configLatch = config
    let otherThreadUpdated = LockedFlag()
    context.onResetRestOfSDK = { context in
      // Waits on another thread that needs the identity's lock. If the
      // identity were still locked, this would time out.
      let done = DispatchSemaphore(value: 0)
      Thread {
        context.update(.end(.configuration))
        done.signal()
      }
      .start()
      otherThreadUpdated.set(done.wait(timeout: .now() + 2) == .success)
    }

    context.dispatch(identify("user-2"))

    #expect(otherThreadUpdated.value)
    let duringReset = context.stateDuringReset
    #expect(duringReset?.appUserId == "user-2")
    #expect(duringReset?.isReady == false)
    #expect(duringReset?.pendingSummary.contains("reset") == true)
    // Saved again after the reset, which wipes storage.
    let events = context.events
    let resetIndex = events.firstIndex(of: "resetRestOfSDK")
    let lastPersist = events.lastIndex(of: "persist")
    #expect(resetIndex != nil)
    #expect(lastPersist != nil && lastPersist! > resetIndex!)
    #expect(context.persisted.last?.appUserId == "user-2")
    // The reset's pending work is gone once dispatch returns.
    #expect(context.state.pendingSummary == ["seed:user-2"])
    config.open()
    await context.settle()
    #expect(context.state.isReady)
  }

  @Test("A change from another thread during the reset applies before that call returns")
  func changeDuringResetIsApplied() async {
    let context = FakeIdentityContext(readyState(appUserId: "user-1"))
    let seenByOtherThread = LockedValue<[String: Any]>([:])
    context.onResetRestOfSDK = { context in
      let done = DispatchSemaphore(value: 0)
      Thread {
        context.dispatch(.mergeAttributes(["plan": "pro"], shouldTrack: false, shouldNotify: false))
        // Read straight after, on the same thread.
        seenByOtherThread.set(context.state.userAttributes)
        done.signal()
      }
      .start()
      _ = done.wait(timeout: .now() + 2)
    }

    context.dispatch(identify("user-2"))

    #expect(seenByOtherThread.value["plan"] as? String == "pro")
    #expect(context.state.userAttributes["plan"] as? String == "pro")
    #expect(context.state.appUserId == "user-2")
    await context.settle()
  }

  @Test("If no kept attributes were gathered, the switch gathers them once unlocked")
  func switchGathersKeptAttributesLate() async {
    let context = FakeIdentityContext(readyState(appUserId: "user-1"))
    context.keptAttributes = ["acquisition_source": "network"]

    // As when another thread logged user-1 in after the caller checked.
    context.dispatch(identify("user-2", keptAttributes: nil))

    #expect(context.events.contains("attributesKeptAcrossReset"))
    #expect(context.state.userAttributes["acquisition_source"] as? String == "network")
    #expect(context.state.appUserId == "user-2")
    await context.settle()
  }

  @Test("Merges land on the user identified before them, in order")
  func mergesFollowIdentify() async {
    let context = FakeIdentityContext(readyState(appUserId: "user-1"))

    context.dispatch(.mergeAttributes(["a": 1], shouldTrack: false, shouldNotify: false))
    context.dispatch(identify("user-2", keptAttributes: [:]))
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

  // MARK: - Assignments

  @Test("identify waits for assignments only when restoring them")
  func identifyRestoringAssignments() async {
    let context = FakeIdentityContext(readyState())
    let assignments = Latch()
    context.assignmentsLatch = assignments

    context.dispatch(identify("user-1", restoreAssignments: true))
    #expect(context.state.pendingSummary.contains("assignments:user-1"))
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

    context.dispatch(identify("user-1"))
    // Only the seed is outstanding: no config latch, so it resolves at once.
    #expect(await eventually { context.state.isReady })
    #expect(context.state.pending.isEmpty)
    assignments.open()
    await context.settle()
  }

  @Test("Restoring an earlier user's assignments doesn't make the next user ready")
  func staleAssignmentsDontMakeNextUserReady() async {
    let context = FakeIdentityContext(readyState())
    let first = Latch()
    let second = Latch()
    context.assignmentsLatches = [first, second]

    context.dispatch(identify("user-1", restoreAssignments: true))
    // So that user-1's fetch takes the first latch.
    #expect(await eventually { context.events.contains("fetchAssignments") })
    context.dispatch(identify("user-2", restoreAssignments: true, keptAttributes: [:]))
    first.open()
    #expect(await eventually { !context.state.pendingSummary.contains("assignments:user-1") })

    #expect(context.state.pendingSummary.contains("assignments:user-2"))
    #expect(context.state.isReady == false)

    second.open()
    await context.settle()
    #expect(context.state.isReady)
  }

  @Test("Restoring assignments for a user identified again waits for the latest restore")
  func sameUserRestoredTwiceWaitsForLatest() async {
    let context = FakeIdentityContext(readyState())
    let first = Latch()
    let second = Latch()
    context.assignmentsLatches = [first, second]

    context.dispatch(identify("user-1", restoreAssignments: true))
    #expect(await eventually { context.events.contains("fetchAssignments") })
    context.dispatch(.reset(keptAttributes: [:]))
    context.dispatch(identify("user-1", restoreAssignments: true))
    #expect(await eventually { context.events.filter { $0 == "fetchAssignments" }.count == 2 })

    first.open()
    #expect(await eventually {
      context.state.pendingSummary.filter { $0 == "assignments:user-1" }.count == 1
    })
    // The second restore is still running, so the user isn't ready.
    #expect(context.state.isReady == false)

    second.open()
    #expect(await eventually { context.state.isReady })
    await context.settle()
  }

  // MARK: - Seed

  @Test("The seed comes from the user id once the config allows it")
  func seedFromConfig() async {
    let context = FakeIdentityContext(readyState())
    context.seeds["user-1"] = 7
    let config = Latch()
    context.configLatch = config

    context.dispatch(identify("user-1"))
    #expect(context.state.pendingSummary == ["seed:user-1"])
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

    context.dispatch(identify("user-1"))
    context.dispatch(.mergeAttributes(["plan": "pro"], shouldTrack: false, shouldNotify: false))

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

    context.dispatch(identify("user-1"))
    context.dispatch(identify("user-2", keptAttributes: [:]))
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

    context.dispatch(identify("user-1"))
    context.dispatch(.reset(keptAttributes: [:]))
    #expect(context.state.appUserId == nil)
    #expect(context.state.isReady == false)

    config.open()
    await context.settle()
    #expect(context.state.isReady)
    #expect(context.state.seed != 7)
  }

  // MARK: - Attributes

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

  @Test("reset gives the user a new anonymous identity with the kept attributes")
  func reset() async {
    let context = FakeIdentityContext(readyState(appUserId: "user-1", userAttributes: ["a": 1]))

    context.dispatch(.reset(keptAttributes: ["acquisition_source": "network"]))

    let state = context.state
    #expect(state.appUserId == nil)
    #expect(state.aliasId != "$SuperwallAlias:alias-1")
    #expect(state.aliasId.hasPrefix(IdentityLogic.superwallPrefix))
    #expect(state.userAttributes["a"] == nil)
    #expect(state.userAttributes["acquisition_source"] as? String == "network")
    #expect(state.userAttributes["aliasId"] as? String == state.aliasId)
    #expect(state.isReady)
    #expect(context.events.contains("resetRestOfSDK"))
    #expect(context.stateDuringReset?.isReady == false)
    #expect(context.persisted.last?.aliasId == state.aliasId)
    #expect(context.tracked.count == 1)
    // Unready during the reset, ready again once it's done.
    #expect(context.readiness == [false, true])
    await context.settle()
  }

  @Test("persist saves the identity as it is")
  func persist() async {
    let context = FakeIdentityContext(readyState(appUserId: "user-1"))
    context.dispatch(.persist)
    #expect(context.persisted.last?.appUserId == "user-1")
  }

  @Test("A pending reset keeps the identity from being ready until it ends")
  func pendingResetBlocksReadiness() {
    let context = FakeIdentityContext(readyState(appUserId: "user-1"))
    let reset = UUID()

    context.update(.begin(.reset(reset)))
    #expect(context.state.isReady == false)
    context.update(.end(.reset(reset)))
    #expect(context.state.isReady)
    #expect(context.readiness == [false, true])
  }

  // MARK: - Observers

  @Test("Updates from different threads save one at a time, in order")
  func persistenceIsSerialized() {
    let store = IdentityStore(initial: readyState())
    let firstSaving = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let saves = LockedValue<[String]>([])
    let isFirstSave = LockedFlag()
    isFirstSave.set(true)

    IdentityObservers.install(
      on: store,
      persist: { _, after in
        let first = isFirstSave.value
        isFirstSave.set(false)
        saves.mutate { $0.append("start \(after.appUserId ?? "anonymous")") }
        if first {
          firstSaving.signal()
          // Hold the first save. Another update meanwhile must wait for it
          // rather than save alongside it, or the two can land out of order.
          _ = release.wait(timeout: .now() + 0.5)
        }
        saves.mutate { $0.append("end \(after.appUserId ?? "anonymous")") }
      },
      readinessChanged: { _ in }
    )

    let finished = DispatchSemaphore(value: 0)
    Thread {
      store.update(IdentityUpdate.identify(IdentifyOperation(userId: "user-1")))
      finished.signal()
    }
    .start()
    firstSaving.wait()

    Thread {
      store.update(IdentityUpdate.reset(aliasId: "$SuperwallAlias:new", seed: 1))
      finished.signal()
    }
    .start()
    // Give the second update the chance to save alongside the first.
    Thread.sleep(forTimeInterval: 0.1)
    release.signal()
    finished.wait()
    finished.wait()

    #expect(saves.value == ["start user-1", "end user-1", "start anonymous", "end anonymous"])
  }

  @Test("A side effect that finishes after the identity is gone does nothing")
  func sideEffectAfterContextIsGone() async {
    var context: FakeIdentityContext? = FakeIdentityContext(readyState())
    let config = Latch()
    context?.configLatch = config
    context?.dispatch(identify("user-1"))
    let sideEffects = context?.takeSideEffects() ?? []
    weak var released = context

    // The side effects hold the context weakly, so this frees it while the
    // seed lookup is still waiting for the config.
    context = nil
    #expect(released == nil)

    config.open()
    for task in sideEffects {
      await task.value
    }
  }

  @Test("Debug descriptions leave out user ids and attribute values")
  func descriptionsHidePersonalData() {
    let identify = IdentityAction.identify(
      userId: "secret-user",
      restoreAssignments: true,
      keptAttributes: ["acquisition_source": "secret-network"]
    )
    let merge = IdentityAction.mergeAttributes(["email": "secret@example.com"], shouldTrack: true, shouldNotify: false)
    let reset = IdentityAction.reset(keptAttributes: ["campaign": "secret-campaign"])
    #expect(String(describing: identify).contains("secret") == false)
    #expect(String(describing: merge).contains("secret") == false)
    #expect(String(describing: reset).contains("secret") == false)
    #expect(String(describing: merge).contains("email"))
    #expect(String(describing: IdentityAction.resolveSeed(IdentifyOperation(userId: "secret-user"), seed: 7)) == "resolveSeed(seed: 7)")
    #expect(String(describing: IdentityAction.resolveSeed(IdentifyOperation(userId: "secret-user"), seed: nil)) == "resolveSeed(seed: nil)")
    #expect(String(describing: IdentityAction.persist) == "persist")
  }
}

/// A flag shared with other threads.
private final class LockedFlag: @unchecked Sendable {
  private let lock = NSLock()
  private var _value = false

  var value: Bool {
    lock.lock()
    defer { lock.unlock() }
    return _value
  }

  func set(_ value: Bool) {
    lock.lock()
    _value = value
    lock.unlock()
  }
}

/// A value shared with other threads.
private final class LockedValue<Value>: @unchecked Sendable {
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

  func mutate(_ body: (inout Value) -> Void) {
    lock.lock()
    body(&_value)
    lock.unlock()
  }
}
