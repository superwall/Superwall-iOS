import Foundation
import Testing
@testable import SuperwallKit

private let userId = "supabase-user-123"
/// The SHA256 bucket for `userId`.
private let derivedSeed = 71
/// The random seed the user starts with.
private let storedSeed = 42

/// Leaves assignments alone, so no test reaches the network.
private final class NoAssignmentsConfigManager: ConfigManager, @unchecked Sendable {
  override func getAssignments() async throws {}
}

/// Builds an identity manager on its own storage and config, so tests don't
/// share state. A second harness on the same storage acts as the next launch.
private struct Harness {
  let dependencyContainer: DependencyContainer
  let storage: StorageMock
  let configManager: ConfigManager
  let identityManager: IdentityManager

  init(
    enableUserIdSeed: Bool,
    storage: StorageMock = StorageMock()
  ) {
    let options = SuperwallOptions()
    options.enableUserIdSeed = enableUserIdSeed
    let dependencyContainer = DependencyContainer()
    let configManager = NoAssignmentsConfigManager(
      options: options,
      storeKitManager: dependencyContainer.storeKitManager,
      storage: storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    if storage.get(Seed.self) == nil {
      storage.save(storedSeed, forType: Seed.self)
    }
    self.dependencyContainer = dependencyContainer
    self.storage = storage
    self.configManager = configManager
    self.identityManager = IdentityManager(
      deviceHelper: dependencyContainer.deviceHelper,
      storage: storage,
      configManager: configManager,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer
    ) { _ in
      // Tracks nothing: the default would track to the shared instance.
    }
  }

  func configArrives(remoteEnabled: Bool) {
    var config = Config.stub()
    config.triggers = []
    config.featureFlags.enableUserIdSeed = remoteEnabled
    configManager.store.update(ConfigUpdate.retrieved(config))
  }

  func configFails() {
    configManager.store.update(ConfigUpdate.failed(URLError(.notConnectedToInternet)))
  }
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
    try? await Task.sleep(nanoseconds: 10_000_000)
  }
  return condition()
}

/// Waits long enough for queued identity work that shouldn't change anything
/// to have had the chance to.
private func settle() async {
  try? await Task.sleep(nanoseconds: 200_000_000)
}

@Suite("User id seeds")
struct UserIdSeedTests {
  @Test(arguments: [
    (false, false, storedSeed),
    (false, true, derivedSeed),
    (true, false, derivedSeed),
    (true, true, derivedSeed)
  ])
  func identifyUsesTheOptionOrTheRemoteFlag(
    enabled: Bool,
    remoteEnabled: Bool,
    expectedSeed: Int
  ) async {
    let harness = Harness(enableUserIdSeed: enabled)
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager
    harness.configArrives(remoteEnabled: remoteEnabled)

    identityManager.identify(userId: "  \(userId)\n", options: nil)
    #expect(await eventually { identityManager.identitySubject.value })
    await settle()

    #expect(identityManager.appUserId == userId)
    #expect(identityManager.seed == expectedSeed)
    #expect(identityManager.userAttributes["seed"] as? Int == expectedSeed)
    #expect(await eventually { harness.storage.get(Seed.self) == expectedSeed })
    #expect(await eventually { harness.storage.get(SeedAwaitsConfig.self) == nil })
  }

  @Test("With the option on, the seed is set and saved with the user id, before identify returns")
  func optionSetsTheSeedWithTheUserId() async {
    let harness = Harness(enableUserIdSeed: true)
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager
    // No config: the option doesn't need it.

    identityManager.identify(userId: userId, options: nil)

    #expect(identityManager.appUserId == userId)
    #expect(identityManager.seed == derivedSeed)
    #expect(identityManager.userAttributes["seed"] as? Int == derivedSeed)
    #expect(identityManager.store.state.pending.isEmpty)
    #expect(await eventually { harness.storage.get(AppUserId.self) == userId })
    #expect(harness.storage.get(Seed.self) == derivedSeed)
    #expect(harness.storage.get(SeedAwaitsConfig.self) == nil)
  }

  @Test("With the option on, the seed is derived even when the config fails to load")
  func optionDoesNotNeedRemoteConfig() async {
    let harness = Harness(enableUserIdSeed: true)
    defer { withExtendedLifetime(harness) {} }
    harness.configFails()

    harness.identityManager.identify(userId: userId, options: nil)

    #expect(harness.identityManager.seed == derivedSeed)
  }

  @Test("A user identified while the config fails to load gets their seed on the next launch")
  func seedIsDerivedOnTheNextLaunchAfterConfigFailed() async {
    let storage = StorageMock()
    let firstLaunch = Harness(enableUserIdSeed: false, storage: storage)
    firstLaunch.configFails()

    firstLaunch.identityManager.identify(userId: userId, options: nil)
    #expect(await eventually { firstLaunch.identityManager.identitySubject.value })
    #expect(firstLaunch.identityManager.seed == storedSeed)
    #expect(await eventually { storage.get(SeedAwaitsConfig.self) == true })
    #expect(await eventually { storage.get(AppUserId.self) == userId })
    withExtendedLifetime(firstLaunch) {}

    let nextLaunch = Harness(enableUserIdSeed: false, storage: storage)
    defer { withExtendedLifetime(nextLaunch) {} }
    let identityManager = nextLaunch.identityManager
    storage.neverCalledStaticConfig = false
    #expect(identityManager.appUserId == userId)
    #expect(identityManager.seed == storedSeed)

    await identityManager.configure()
    // The app identifies the same user again, as it does on every launch.
    identityManager.identify(userId: userId, options: nil)
    await settle()
    // Not ready until the config has said what the seed is.
    #expect(identityManager.identitySubject.value == false)

    nextLaunch.configArrives(remoteEnabled: true)

    #expect(await eventually { identityManager.seed == derivedSeed })
    #expect(await eventually { identityManager.identitySubject.value })
    #expect(identityManager.userAttributes["seed"] as? Int == derivedSeed)
    #expect(await eventually { storage.get(Seed.self) == derivedSeed })
    #expect(await eventually { storage.get(SeedAwaitsConfig.self) == nil })
  }

  @Test("A seed left waiting keeps the random seed when the next launch's config has user id seeds off")
  func seedLeftWaitingStaysRandomWhenRemoteIsOff() async {
    let storage = StorageMock()
    storage.save(userId, forType: AppUserId.self)
    storage.save(storedSeed, forType: Seed.self)
    storage.save(true, forType: SeedAwaitsConfig.self)
    storage.neverCalledStaticConfig = false
    let harness = Harness(enableUserIdSeed: false, storage: storage)
    defer { withExtendedLifetime(harness) {} }
    harness.configArrives(remoteEnabled: false)

    await harness.identityManager.configure()

    #expect(await eventually { harness.identityManager.identitySubject.value })
    #expect(harness.identityManager.seed == storedSeed)
    #expect(await eventually { storage.get(SeedAwaitsConfig.self) == nil })
  }

  @Test("A reset before the config loads keeps the new anonymous seed")
  func resetBeforeConfigLoadsKeepsTheNewSeed() async {
    let harness = Harness(enableUserIdSeed: false)
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager

    identityManager.identify(userId: userId, options: nil)
    identityManager.reset()
    let seedAfterReset = identityManager.seed

    harness.configArrives(remoteEnabled: true)
    #expect(await eventually { identityManager.identitySubject.value })
    await settle()

    #expect(identityManager.appUserId == nil)
    #expect(identityManager.seed == seedAfterReset)
    #expect(await eventually { harness.storage.get(Seed.self) == seedAfterReset })
    #expect(harness.storage.get(SeedAwaitsConfig.self) == nil)
  }

  @Test(
    "A user who was already identified keeps their seed, on identify and on launch",
    arguments: [true, false]
  )
  func alreadyIdentifiedUserKeepsTheirSeed(enabled: Bool) async {
    let storage = StorageMock()
    storage.save(userId, forType: AppUserId.self)
    storage.save(storedSeed, forType: Seed.self)
    storage.neverCalledStaticConfig = false
    let harness = Harness(enableUserIdSeed: enabled, storage: storage)
    defer { withExtendedLifetime(harness) {} }
    let identityManager = harness.identityManager
    harness.configArrives(remoteEnabled: true)

    await identityManager.configure()
    identityManager.identify(userId: userId, options: nil)
    await settle()

    #expect(identityManager.seed == storedSeed)
    #expect(identityManager.userAttributes["seed"] as? Int != derivedSeed)
    #expect(storage.get(Seed.self) == storedSeed)
    #expect(identityManager.identitySubject.value)
  }

  @Test
  func optionDefaultsToFalseAndIsEncoded() {
    let options = SuperwallOptions()
    #expect(options.enableUserIdSeed == false)
    #expect(options.toDictionary()["enableUserIdSeed"] as? Bool == false)

    options.enableUserIdSeed = true
    #expect(options.toDictionary()["enableUserIdSeed"] as? Bool == true)
  }

  @Test
  func optionIsAvailableToObjectiveC() {
    let options = SuperwallOptions()
    options.setValue(true, forKey: "enableUserIdSeed")
    #expect(options.enableUserIdSeed)
  }
}
