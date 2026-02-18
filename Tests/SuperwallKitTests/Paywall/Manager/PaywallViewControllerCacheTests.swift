//
//  PaywallCacheTests.swift
//
//
//  Created by Yusuf Tör on 09/03/2022.
//

// swiftlint:disable all

import Testing
@testable import SuperwallKit

struct PaywallViewControllerCacheTests {
  @Test
  @MainActor
  func saveAndRetrievePaywall() throws {
    // Given
    let dependencyContainer = DependencyContainer()
    let locale = dependencyContainer.deviceHelper.localeIdentifier
    let paywallCache = PaywallViewControllerCache(deviceLocaleString: locale)
    let id = "myid"
    let key = PaywallCacheLogic.key(identifier: id, locale: locale)
    let paywall = dependencyContainer.makePaywallViewController(
      for: .stub(),
      withCache: paywallCache,
      withPaywallArchiveManager: nil,
      delegate: nil
    )
    paywall.cacheKey = key

    // When
    paywallCache.save(paywall, forKey: key)

    let cachedPaywall = paywallCache.getPaywallViewController(forKey: key)

    // Then
    #expect(cachedPaywall == paywall)
  }

  @Test
  @MainActor
  func saveAndRemovePaywall_withId() {
    // Given
    let dependencyContainer = DependencyContainer()
    let locale = dependencyContainer.deviceHelper.localeIdentifier
    let paywallCache = PaywallViewControllerCache(deviceLocaleString: locale)
    let id = "myid"
    let key = PaywallCacheLogic.key(identifier: id, locale: locale)
    let paywall = dependencyContainer.makePaywallViewController(
      for: .stub(),
      withCache: paywallCache,
      withPaywallArchiveManager: nil,
      delegate: nil
    )
    paywall.cacheKey = key

    // When
    paywallCache.save(paywall, forKey: key)

    var cachedPaywall = paywallCache.getPaywallViewController(forKey: key)

    #expect(cachedPaywall == paywall)

    paywallCache.removePaywallViewController(forKey: key)

    // Then
    cachedPaywall = paywallCache.getPaywallViewController(forKey: key)

    #expect(cachedPaywall == nil)
  }

  @Test
  @MainActor
  func clearCache() {
    // Given
    let dependencyContainer = DependencyContainer()
    let locale = dependencyContainer.deviceHelper.localeIdentifier
    let paywallCache = PaywallViewControllerCache(deviceLocaleString: locale)
    let paywallId1 = "id1"
    let key1 = PaywallCacheLogic.key(identifier: paywallId1, locale: locale)

    let paywall1 = dependencyContainer.makePaywallViewController(
      for: .stub(),
      withCache: paywallCache,
      withPaywallArchiveManager: nil,
      delegate: nil
    )
    paywall1.cacheKey = key1

    let paywallId2 = "id2"
    let key2 = PaywallCacheLogic.key(identifier: paywallId2, locale: locale)
    let paywall2 = dependencyContainer.makePaywallViewController(
      for: .stub(),
      withCache: paywallCache,
      withPaywallArchiveManager: nil,
      delegate: nil
    )
    paywall2.cacheKey = key2

    // When
    paywallCache.save(paywall1, forKey: key1)
    paywallCache.save(paywall2, forKey: key2)

    let cachedPaywall1 = paywallCache.getPaywallViewController(forKey: key1)
    let cachedPaywall2 = paywallCache.getPaywallViewController(forKey: key2)

    #expect(cachedPaywall1 == paywall1)
    #expect(cachedPaywall2 == paywall2)

    paywallCache.removeAll()

    // Then
    let nilPaywall1 = paywallCache.getPaywallViewController(forKey: key1)
    let nilPaywall2 = paywallCache.getPaywallViewController(forKey: key2)

    #expect(nilPaywall1 == nil)
    #expect(nilPaywall2 == nil)
  }
}
