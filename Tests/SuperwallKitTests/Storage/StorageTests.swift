//
//  File.swift
//
//
//  Created by Yusuf Tör on 15/09/2023.
//
// swiftlint:disable all

import XCTest
import Testing
@testable import SuperwallKit

class StorageTests: XCTestCase {
  func test_overwriteAssignments() {
    let dependencyContainer = DependencyContainer()
    let storage = Storage(factory: dependencyContainer)
    let network = NetworkMock(
      options: SuperwallOptions(),
      factory: dependencyContainer
    )

    let assignments = Set([
      Assignment(
        experimentId: "123",
        variant: .init(id: "1", type: .treatment, paywallId: "23"),
        isSentToServer: false
      )
    ])
    storage.overwriteAssignments(assignments)

    let retrievedAssignments = storage.getAssignments()
    XCTAssertEqual(retrievedAssignments.first, assignments.first)

    storage.reset()

    let retrievedAssignments2 = storage.getAssignments()
    XCTAssertTrue(retrievedAssignments2.isEmpty)
  }
}

// MARK: - API Key Change Cache Clearing

@Suite
struct StorageApiKeyChangeTests {
  @Test
  func clearsCachedConfigWhenApiKeyChanges() {
    let cache = CacheMock()
    let storage = Storage(
      factory: StorageMock.DeviceInfoFactoryMock(),
      cache: cache
    )

    // Configure with key A and save a config
    storage.configure(apiKey: "key_A")
    let config = Config.stub()
    storage.save(config, forType: LatestConfig.self)
    let enrichment = Enrichment(user: JSON([:] as [String: Any]), device: JSON([:] as [String: Any]))
    storage.save(enrichment, forType: LatestEnrichment.self)
    storage.save(true, forType: IsTestModeActiveSubscription.self)

    // Verify data is cached
    let cachedConfig: Config? = storage.get(LatestConfig.self)
    #expect(cachedConfig != nil)
    let cachedEnrichment: Enrichment? = storage.get(LatestEnrichment.self)
    #expect(cachedEnrichment != nil)
    let cachedTestMode: Bool? = storage.get(IsTestModeActiveSubscription.self)
    #expect(cachedTestMode == true)

    // Reconfigure with key B
    storage.configure(apiKey: "key_B")

    // Verify caches are cleared
    let clearedConfig: Config? = storage.get(LatestConfig.self)
    #expect(clearedConfig == nil)
    let clearedEnrichment: Enrichment? = storage.get(LatestEnrichment.self)
    #expect(clearedEnrichment == nil)
    let clearedTestMode: Bool? = storage.get(IsTestModeActiveSubscription.self)
    #expect(clearedTestMode == nil)
  }

  @Test
  func doesNotClearCacheWhenApiKeyIsSame() {
    let cache = CacheMock()
    let storage = Storage(
      factory: StorageMock.DeviceInfoFactoryMock(),
      cache: cache
    )

    // Configure with key A and save a config
    storage.configure(apiKey: "key_A")
    let config = Config.stub()
    storage.save(config, forType: LatestConfig.self)

    // Reconfigure with same key
    storage.configure(apiKey: "key_A")

    // Verify cache is still present
    let cachedConfig: Config? = storage.get(LatestConfig.self)
    #expect(cachedConfig != nil)
  }

  @Test
  func storesApiKeyOnFirstConfigure() {
    let cache = CacheMock()
    let storage = Storage(
      factory: StorageMock.DeviceInfoFactoryMock(),
      cache: cache
    )

    // No previous key stored
    let previousKey: String? = storage.get(LastApiKey.self)
    #expect(previousKey == nil)

    // Configure for the first time
    storage.configure(apiKey: "key_A")

    // Key should now be stored
    let storedKey: String? = storage.get(LastApiKey.self)
    #expect(storedKey == "key_A")
  }

  @Test
  func doesNotClearCacheOnFirstConfigure() {
    let cache = CacheMock()
    let storage = Storage(
      factory: StorageMock.DeviceInfoFactoryMock(),
      cache: cache
    )

    // Pre-populate a config before first configure
    let config = Config.stub()
    storage.save(config, forType: LatestConfig.self)

    // First configure (no previous key)
    storage.configure(apiKey: "key_A")

    // Config should still be present since there's no previous key to differ from
    let cachedConfig: Config? = storage.get(LatestConfig.self)
    #expect(cachedConfig != nil)
  }
}

