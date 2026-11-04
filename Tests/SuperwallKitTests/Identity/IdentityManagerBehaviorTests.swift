//
//  IdentityManagerBehaviorTests.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Lets a test hold `getAssignments()` open until it says so.
private final class AssignmentsGate: @unchecked Sendable {
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

/// Counts calls to `getAssignments()` and can hold them open.
private final class AssignmentsSpyConfigManager: ConfigManager, @unchecked Sendable {
  private let lock = NSLock()
  private var _getAssignmentsCount = 0
  var gate: AssignmentsGate?

  var getAssignmentsCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return _getAssignmentsCount
  }

  override func getAssignments() async throws {
    lock.lock()
    _getAssignmentsCount += 1
    lock.unlock()
    await gate?.wait()
  }
}

/// Builds an identity manager on its own storage, so tests don't share state.
private struct Harness {
  let dependencyContainer: DependencyContainer
  let storage: StorageMock
  let configManager: AssignmentsSpyConfigManager
  let identityManager: IdentityManager

  /// - Parameter publishConfig: Whether to start with a config that doesn't
  ///   derive seeds from user ids. A newly identified user isn't ready until
  ///   the config has said whether to.
  init(
    storage: StorageMock = StorageMock(),
    publishConfig: Bool = true,
    notifyUserChange: (([String: Any]) -> Void)? = nil
  ) {
    let dependencyContainer = DependencyContainer()
    let configManager = AssignmentsSpyConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    self.dependencyContainer = dependencyContainer
    self.storage = storage
    self.configManager = configManager
    self.identityManager = IdentityManager(
      deviceHelper: dependencyContainer.deviceHelper,
      storage: storage,
      configManager: configManager,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      notifyUserChange: notifyUserChange,
      // Kept off the shared instance, which the defaults would reset and track to.
      resetForNewUser: {},
      track: { _ in }
    )
    if publishConfig {
      configManager.store.update(ConfigUpdate.retrieved(config(enableUserIdSeed: false)))
    }
  }

  var appInstalledAtString: String {
    dependencyContainer.deviceHelper.appInstalledAtString
  }
}

/// Polls `condition` until it holds or `timeout` passes.
@discardableResult
private func eventually(
  timeout: TimeInterval = 3,
  _ condition: () -> Bool
) async -> Bool {
  let deadline = Date().addingTimeInterval(timeout)
  while Date() < deadline {
    if condition() {
      return true
    }
    try? await Task.sleep(nanoseconds: 10_000_000)
  }
  return condition()
}

/// Waits long enough for queued identity work that shouldn't change anything
/// to have had the chance to.
private func settle() async {
  try? await Task.sleep(nanoseconds: 200_000_000)
}

private func aliasUUID(of identityManager: IdentityManager) -> UUID? {
  UUID(
    uuidString: identityManager.aliasId.replacingOccurrences(
      of: IdentityLogic.superwallPrefix,
      with: ""
    )
  )
}

private func config(enableUserIdSeed: Bool) -> Config {
  var config = Config.stub()
  config.featureFlags.enableUserIdSeed = enableUserIdSeed
  return config
}

@Suite("IdentityManager behavior")
struct IdentityManagerBehaviorTests {
  // MARK: - Initial state

  @Test("A fresh install generates and saves an alias and a seed")
  func freshInstallGeneratesIds() async {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager

    #expect(identityManager.aliasId.hasPrefix(IdentityLogic.superwallPrefix))
    #expect((0..<100).contains(identityManager.seed))
    #expect(harness.storage.get(AliasId.self) == identityManager.aliasId)
    #expect(harness.storage.get(Seed.self) == identityManager.seed)
    #expect(identityManager.appUserId == nil)
    #expect(identityManager.isLoggedIn == false)
    #expect(identityManager.userId == identityManager.aliasId)

    let hasIds = await eventually {
      identityManager.userAttributes["aliasId"] as? String == identityManager.aliasId
        && identityManager.userAttributes["seed"] as? Int == identityManager.seed
    }
    #expect(hasIds)
  }

  @Test("Stored ids are restored on launch")
  func storedIdsAreRestored() {
    let storage = StorageMock()
    storage.save("$SuperwallAlias:stored", forType: AliasId.self)
    storage.save(42, forType: Seed.self)
    storage.save("stored-user", forType: AppUserId.self)
    storage.save(["custom": "value"], forType: UserAttributes.self)
    storage.save(true, forType: DidCleanUserAttributes.self)

    let harness = Harness(storage: storage)
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager

    #expect(identityManager.aliasId == "$SuperwallAlias:stored")
    #expect(identityManager.seed == 42)
    #expect(identityManager.appUserId == "stored-user")
    #expect(identityManager.userId == "stored-user")
    #expect(identityManager.isLoggedIn)
    #expect(identityManager.userAttributes["custom"] as? String == "value")
  }

  @Test("Attributes that can't be represented as JSON are cleaned once on launch")
  func cleansNonJSONAttributesOnce() async {
    let storage = StorageMock()
    storage.save("$SuperwallAlias:stored", forType: AliasId.self)
    storage.save(42, forType: Seed.self)
    storage.save(
      // Dates are archivable, but they aren't JSON.
      ["valid": "value", "invalid": Date()],
      forType: UserAttributes.self
    )

    let harness = Harness(storage: storage)
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager

    let cleaned = await eventually {
      storage.get(DidCleanUserAttributes.self) == true
    }
    #expect(cleaned)
    let attributes = identityManager.userAttributes
    #expect(attributes["valid"] as? String == "value")
    #expect(attributes["invalid"] == nil)
  }

  @Test("appAccountToken is the userId when it's a UUID, otherwise the alias's UUID")
  func appAccountToken() async {
    let uuid = UUID()
    let uuidHarness = Harness()
    defer { withExtendedLifetime(uuidHarness) {} }
    let uuidUser = uuidHarness.identityManager
    uuidUser.identify(userId: uuid.uuidString, options: nil)
    #expect(await eventually { uuidUser.appUserId == uuid.uuidString })
    #expect(uuidUser.appAccountToken == uuid)

    let namedHarness = Harness()
    defer { withExtendedLifetime(namedHarness) {} }
    let namedUser = namedHarness.identityManager
    namedUser.identify(userId: "not-a-uuid", options: nil)
    #expect(await eventually { namedUser.appUserId == "not-a-uuid" })
    #expect(namedUser.appAccountToken == aliasUUID(of: namedUser))

    let anonymousHarness = Harness()
    let anonymousUser = anonymousHarness.identityManager
    #expect(anonymousUser.appAccountToken != nil)
    #expect(anonymousUser.appAccountToken == aliasUUID(of: anonymousUser))
  }

  // MARK: - Configure

  @Test("configure marks the identity ready without assignments for a new user")
  func configureWithoutAssignments() async {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    harness.storage.neverCalledStaticConfig = false
    #expect(harness.identityManager.identitySubject.value == false)

    await harness.identityManager.configure()

    #expect(await eventually { harness.identityManager.identitySubject.value })
    #expect(harness.configManager.getAssignmentsCount == 0)
  }

  @Test("configure waits for assignments for a user that predates static config")
  func configureWaitsForAssignments() async {
    let storage = StorageMock()
    storage.save("legacy-user", forType: AppUserId.self)
    let harness = Harness(storage: storage)
    defer { withExtendedLifetime(harness) {} }
    harness.storage.neverCalledStaticConfig = true
    let gate = AssignmentsGate()
    harness.configManager.gate = gate

    let configure = Task {
      await harness.identityManager.configure()
    }
    #expect(await eventually { harness.configManager.getAssignmentsCount == 1 })
    await settle()
    #expect(harness.identityManager.identitySubject.value == false)

    gate.open()
    await configure.value
    #expect(await eventually { harness.identityManager.identitySubject.value })
  }

  @Test("hasIdentity only emits once the identity is ready")
  func hasIdentityEmitsWhenReady() async throws {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    harness.storage.neverCalledStaticConfig = false

    let emitted = Task {
      try await harness.identityManager.hasIdentity.throwableAsync()
    }
    await settle()
    await harness.identityManager.configure()

    // Bounded first, so a regression fails here instead of hanging.
    guard await eventually({ harness.identityManager.identitySubject.value }) else {
      emitted.cancel()
      Issue.record("the identity never became ready")
      return
    }
    #expect(try await emitted.value == true)
  }

  // MARK: - Identify

  @Test("identify sets and saves the user id and adds it to the attributes")
  func identifySetsUserId() async {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager
    let aliasId = identityManager.aliasId

    identityManager.identify(userId: "user-1", options: nil)

    #expect(await eventually { identityManager.appUserId == "user-1" })
    #expect(identityManager.userId == "user-1")
    #expect(identityManager.isLoggedIn)
    #expect(identityManager.aliasId == aliasId)
    #expect(await eventually { harness.storage.get(AppUserId.self) == "user-1" })
    #expect(await eventually { identityManager.userAttributes["appUserId"] as? String == "user-1" })
    #expect(identityManager.userAttributes["aliasId"] as? String == aliasId)
  }

  @Test("identify trims whitespace from the user id")
  func identifyTrimsWhitespace() async {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager
    identityManager.identify(userId: "  user-1 \n", options: nil)
    #expect(await eventually { identityManager.appUserId == "user-1" })
  }

  @Test("identify ignores an empty or blank user id")
  func identifyIgnoresBlankUserId() async {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    harness.identityManager.identify(userId: "", options: nil)
    harness.identityManager.identify(userId: "   \n", options: nil)
    await settle()

    #expect(harness.identityManager.appUserId == nil)
    #expect(harness.configManager.getAssignmentsCount == 0)
  }

  @Test("identifying the current user again does nothing")
  func identifySameUserIsNoOp() async {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager
    identityManager.identify(userId: "user-1", options: nil)
    #expect(await eventually { harness.configManager.getAssignmentsCount == 1 })
    #expect(await eventually { identityManager.identitySubject.value })
    let aliasId = identityManager.aliasId
    let seed = identityManager.seed

    identityManager.identify(userId: "user-1", options: nil)
    await settle()

    #expect(harness.configManager.getAssignmentsCount == 1)
    #expect(identityManager.appUserId == "user-1")
    #expect(identityManager.aliasId == aliasId)
    #expect(identityManager.seed == seed)
    #expect(identityManager.identitySubject.value)
  }

  @Test("identify derives the seed from the user id when the config enables it")
  func identifyDerivesSeed() async throws {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    harness.configManager.store.update(ConfigUpdate.retrieved(config(enableUserIdSeed: true)))
    let expectedSeed = try #require("user-1".sha256MappedToRange())

    harness.identityManager.identify(userId: "user-1", options: nil)

    #expect(await eventually { harness.identityManager.seed == expectedSeed })
    #expect(await eventually { harness.storage.get(Seed.self) == expectedSeed })
    #expect(await eventually {
      harness.identityManager.userAttributes["seed"] as? Int == expectedSeed
    })
  }

  @Test("identify keeps the seed when the config doesn't enable user id seeds")
  func identifyKeepsSeed() async {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    let seed = harness.identityManager.seed
    harness.configManager.store.update(ConfigUpdate.retrieved(config(enableUserIdSeed: false)))

    harness.identityManager.identify(userId: "user-1", options: nil)
    #expect(await eventually { harness.identityManager.identitySubject.value })
    await settle()

    #expect(harness.identityManager.seed == seed)
  }

  @Test("A newly identified user isn't ready until the config arrives, but merges still apply")
  func identifyWaitsForConfig() async {
    let harness = Harness(publishConfig: false)
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager
    harness.storage.neverCalledStaticConfig = false
    await identityManager.configure()
    #expect(await eventually { identityManager.identitySubject.value })

    identityManager.identify(userId: "user-1", options: nil)
    #expect(await eventually { identityManager.appUserId == "user-1" })
    await settle()
    #expect(identityManager.identitySubject.value == false)

    identityManager.mergeUserAttributes(["plan": "pro"])
    #expect(await eventually { identityManager.userAttributes["plan"] as? String == "pro" })

    harness.configManager.store.update(ConfigUpdate.retrieved(config(enableUserIdSeed: false)))
    #expect(await eventually { identityManager.identitySubject.value })
  }

  @Test("identify fetches assignments in the background by default")
  func identifyDoesNotWaitForAssignments() async {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    let gate = AssignmentsGate()
    harness.configManager.gate = gate

    harness.identityManager.identify(userId: "user-1", options: nil)

    #expect(await eventually { harness.configManager.getAssignmentsCount == 1 })
    // Ready while the assignments are still loading.
    #expect(await eventually { harness.identityManager.identitySubject.value })
    gate.open()
  }

  @Test("identify waits for assignments when asked to restore them")
  func identifyWaitsForAssignmentsWhenRestoring() async {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    let gate = AssignmentsGate()
    harness.configManager.gate = gate

    harness.identityManager.identify(
      userId: "user-1",
      options: IdentityOptions(restorePaywallAssignments: true)
    )

    #expect(await eventually { harness.configManager.getAssignmentsCount == 1 })
    await settle()
    #expect(harness.identityManager.identitySubject.value == false)

    gate.open()
    #expect(await eventually { harness.identityManager.identitySubject.value })
  }

  // MARK: - Reset

  @Test("reset gives the user a new anonymous identity")
  func resetCreatesNewAnonymousIdentity() async {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager
    identityManager.identify(userId: "user-1", options: nil)
    identityManager.mergeUserAttributes(["custom": "value"])
    #expect(await eventually {
      identityManager.userAttributes["custom"] as? String == "value"
        && identityManager.identitySubject.value
    })
    let oldAliasId = identityManager.aliasId

    identityManager.reset(duringIdentify: false)

    #expect(await eventually { identityManager.appUserId == nil })
    #expect(identityManager.isLoggedIn == false)
    #expect(identityManager.aliasId != oldAliasId)
    #expect(identityManager.aliasId.hasPrefix(IdentityLogic.superwallPrefix))
    #expect(identityManager.userId == identityManager.aliasId)
    #expect(await eventually { identityManager.identitySubject.value })

    let attributes = identityManager.userAttributes
    #expect(attributes["custom"] == nil)
    #expect(attributes["appUserId"] == nil)
    #expect(attributes["aliasId"] as? String == identityManager.aliasId)
    #expect(attributes["seed"] as? Int == identityManager.seed)
    #expect(harness.storage.get(AliasId.self) == identityManager.aliasId)
    #expect(harness.storage.get(Seed.self) == identityManager.seed)
  }

  // MARK: - User attributes

  @Test("Merging attributes adds, overwrites and removes keys, and saves them")
  func mergeAttributes() async {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager

    identityManager.mergeUserAttributes(["keep": "a", "overwrite": "b", "remove": "c"])
    identityManager.mergeUserAttributes(["overwrite": "B", "remove": nil, "$dollar": 1])

    let merged = await eventually {
      identityManager.userAttributes["overwrite"] as? String == "B"
    }
    #expect(merged)
    let attributes = identityManager.userAttributes
    #expect(attributes["keep"] as? String == "a")
    #expect(attributes.keys.contains("remove") == false)
    // Dollar-prefixed keys are dropped (see IdentityStateTests).
    #expect(attributes.keys.contains("dollar") == false)
    #expect(attributes["applicationInstalledAt"] as? String == harness.appInstalledAtString)

    let saved = harness.storage.get(UserAttributes.self)
    #expect(saved?["overwrite"] as? String == "B")
    #expect(saved?.keys.contains("remove") == false)
  }

  @Test("Merges from many threads are all applied")
  func concurrentMerges() async {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager
    await withTaskGroup(of: Void.self) { group in
      for index in 0..<100 {
        group.addTask {
          identityManager.mergeUserAttributes(["key\(index)": index])
        }
      }
    }
    let allApplied = await eventually {
      let attributes = identityManager.userAttributes
      // `index` is typed explicitly: left to inference it becomes `Int?`, and
      // the key turns into "keyOptional(0)".
      return (0..<100).allSatisfy { (index: Int) in attributes["key\(index)"] as? Int == index }
    }
    #expect(allApplied)
  }

  @Test("Merges dispatched from one thread apply in order")
  func mergesApplyInOrder() async {
    let harness = Harness()
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager
    for index in 0..<50 {
      identityManager.mergeUserAttributes(["counter": index])
    }
    identityManager.mergeUserAttributes(["done": true])
    #expect(await eventually { identityManager.userAttributes["done"] as? Bool == true })
    #expect(identityManager.userAttributes["counter"] as? Int == 49)
  }

  @Test("Merging attributes is reflected in the next merge's notification")
  func notificationsSeeEarlierMerges() async {
    var notifications: [[String: Any]] = []
    let lock = NSLock()
    let harness = Harness(notifyUserChange: { attributes in
      lock.lock()
      notifications.append(attributes)
      lock.unlock()
    })
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager

    identityManager.mergeUserAttributes(["first": 1])
    identityManager.mergeUserAttributesAndNotify(["second": 2])

    let notified = await eventually {
      lock.lock()
      defer { lock.unlock() }
      return notifications.count == 1
    }
    #expect(notified)
    lock.lock()
    let attributes = notifications.first
    lock.unlock()
    #expect(attributes?["first"] as? Int == 1)
    #expect(attributes?["second"] as? Int == 2)
  }
}
