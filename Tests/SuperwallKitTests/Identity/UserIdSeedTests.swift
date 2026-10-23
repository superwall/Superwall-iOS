import Combine
import Foundation
import Testing
@testable import SuperwallKit

@Suite(.serialized)
struct UserIdSeedTests {
  @Test(arguments: [
    (nil as Bool?, false, 42),
    (nil, true, 71),
    (true, false, 71),
    (true, true, 71),
    (false, false, 42),
    (false, true, 42)
  ])
  func identifyResolvesLocalOverrideBeforeRemoteFlag(
    override: Bool?,
    remoteEnabled: Bool,
    expectedSeed: Int
  ) async throws {
    let options = SuperwallOptions()
    options.enableUserIdSeed = override
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
  func explicitOverrideWorksWhenRemoteConfigFails(_ enabled: Bool) async throws {
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
  func optionDefaultsToRemoteAndEncodesExplicitOverrides() {
    let options = SuperwallOptions()
    #expect(options.enableUserIdSeed == nil)
    #expect(options.toDictionary()["enableUserIdSeed"] == nil)

    for enabled in [true, false] {
      options.enableUserIdSeed = enabled
      #expect(options.toDictionary()["enableUserIdSeed"] as? Bool == enabled)
    }
  }

  @Test
  func objectiveCBridgePreservesAllThreeStates() {
    let options = SuperwallOptions()
    for enabled in [true, false] {
      options.setValue(NSNumber(value: enabled), forKey: "enableUserIdSeed")
      #expect(options.enableUserIdSeed == enabled)
      #expect((options.value(forKey: "enableUserIdSeed") as? NSNumber)?.boolValue == enabled)
    }
    options.setValue(nil, forKey: "enableUserIdSeed")
    #expect(options.enableUserIdSeed == nil)
    #expect(options.value(forKey: "enableUserIdSeed") == nil)
  }
}
