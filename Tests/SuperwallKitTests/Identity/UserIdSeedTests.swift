import Combine
import Foundation
import Testing
@testable import SuperwallKit

@Suite(.serialized)
struct UserIdSeedTests {
  @Test(arguments: [
    (false, false, 42),
    (false, true, 71),
    (true, false, 71),
    (true, true, 71)
  ])
  func identifyUsesTheOptionOrTheRemoteFlag(
    enabled: Bool,
    remoteEnabled: Bool,
    expectedSeed: Int
  ) async throws {
    let options = SuperwallOptions()
    options.enableUserIdSeed = enabled
    let cache = CacheMock()
    cache.write(42, forType: Seed.self)
    let dependencies = DependencyContainer(options: options, cache: cache)
    var config = Config.stub()
    config.triggers = []
    config.featureFlags.enableUserIdSeed = remoteEnabled
    dependencies.configManager.configState.send(.retrieved(config))
    let identityManager = try #require(dependencies.identityManager)

    identityManager.identify(userId: "  supabase-user-123\n", options: nil)
    _ = try await identityManager.hasIdentity.first().throwableAsync()

    // 71 is the existing SHA256 bucket for this ID, rather than the anonymous seed.
    #expect(identityManager.seed == expectedSeed)
    #expect(identityManager.userAttributes["seed"] as? Int == expectedSeed)
    #expect(dependencies.storage.get(Seed.self) == expectedSeed)
    #expect(identityManager.appUserId == "supabase-user-123")
    withExtendedLifetime(dependencies) {}
  }

  @Test(arguments: [true, false])
  func optionDoesNotNeedRemoteConfig(_ enabled: Bool) async throws {
    let options = SuperwallOptions()
    options.enableUserIdSeed = enabled
    let cache = CacheMock()
    cache.write(42, forType: Seed.self)
    let dependencies = DependencyContainer(options: options, cache: cache)
    dependencies.configManager.configState.send(completion: .failure(URLError(.notConnectedToInternet)))
    let identityManager = try #require(dependencies.identityManager)

    identityManager.identify(userId: "supabase-user-123", options: nil)
    _ = try await identityManager.hasIdentity.first().throwableAsync()

    #expect(identityManager.seed == (enabled ? 71 : 42))
    withExtendedLifetime(dependencies) {}
  }

  @Test
  func resetBeforeConfigLoadsKeepsTheNewSeed() async throws {
    let cache = CacheMock()
    cache.write(42, forType: Seed.self)
    let dependencies = DependencyContainer(options: SuperwallOptions(), cache: cache)
    let identityManager = try #require(dependencies.identityManager)

    identityManager.identify(userId: "supabase-user-123", options: nil)
    identityManager.reset(duringIdentify: false)
    // The identity queue is serial, so this read runs after the reset.
    let seedAfterReset = identityManager.seed

    var config = Config.stub()
    config.triggers = []
    config.featureFlags.enableUserIdSeed = true
    dependencies.configManager.configState.send(.retrieved(config))
    _ = try await identityManager.hasIdentity.first().throwableAsync()

    #expect(identityManager.appUserId == nil)
    #expect(identityManager.seed == seedAfterReset)
    #expect(dependencies.storage.get(Seed.self) == seedAfterReset)
    withExtendedLifetime(dependencies) {}
  }

  @Test
  func identifyingSameUserDoesNotReassignExistingSeed() {
    let options = SuperwallOptions()
    options.enableUserIdSeed = true
    let cache = CacheMock()
    cache.write(42, forType: Seed.self)
    cache.write("supabase-user-123", forType: AppUserId.self)
    let dependencies = DependencyContainer(options: options, cache: cache)

    dependencies.identityManager.identify(userId: "supabase-user-123", options: nil)

    #expect(dependencies.identityManager.seed == 42)
    #expect(dependencies.storage.get(Seed.self) == 42)
    withExtendedLifetime(dependencies) {}
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
