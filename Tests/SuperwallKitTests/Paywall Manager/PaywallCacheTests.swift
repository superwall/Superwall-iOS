//
//  PaywallCacheTests.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//

// swiftlint:disable all

import XCTest
@testable import SuperwallKit

@MainActor
class PaywallCacheTests: XCTestCase {
  func testSaveAndRetrievePaywall() throws {
    // Given
    let dependencyContainer = DependencyContainer()
    let locale = dependencyContainer.deviceHelper.locale
    let paywallCache = PaywallCache(deviceLocaleString: locale)
    let id = "myid"
    let key = PaywallCacheLogic.key(forIdentifier: id, locale: locale)
    let paywall = dependencyContainer.makePaywallViewController(for: .stub())
    paywall.cacheKey = key

    // When
    PaywallViewController.cache.insert(paywall)

    let cachedPaywall = paywallCache.getPaywallViewController(key: key)

    // Then
    XCTAssertEqual(cachedPaywall, paywall)
  }

  func testSaveAndRemovePaywall_withId() {
    // Given
    let dependencyContainer = DependencyContainer()
    let locale = dependencyContainer.deviceHelper.locale
    let paywallCache = PaywallCache(deviceLocaleString: locale)
    let id = "myid"
    let key = PaywallCacheLogic.key(forIdentifier: id, locale: locale)
    let paywall = dependencyContainer.makePaywallViewController(for: .stub())
    paywall.cacheKey = key

    // When
    PaywallViewController.cache.insert(paywall)

    var cachedPaywall = paywallCache.getPaywallViewController(key: key)

    XCTAssertEqual(cachedPaywall, paywall)

    paywallCache.removePaywallViewController(identifier: id)

    // Then
    cachedPaywall = paywallCache.getPaywallViewController(key: key)

    XCTAssertNil(cachedPaywall)
  }

  func testSaveAndRemovePaywall_withVc() {
    // Given
    let dependencyContainer = DependencyContainer()
    let locale = dependencyContainer.deviceHelper.locale
    let paywallCache = PaywallCache(deviceLocaleString: locale)
    let paywallVc = dependencyContainer.makePaywallViewController(for: .stub())

    // When
    PaywallViewController.cache.insert(paywallVc)

    let key = PaywallCacheLogic.key(
      forIdentifier: paywallVc.paywall.identifier,
      locale: locale
    )

    var cachedPaywallVc = paywallCache.getPaywallViewController(key: key)

    XCTAssertEqual(cachedPaywallVc, paywallVc)

    paywallCache.removePaywallViewController(paywallVc)

    // Then
    cachedPaywallVc = paywallCache.getPaywallViewController(key: key)

    XCTAssertNil(cachedPaywallVc)
  }

  func testClearCache() {
    // Given
    let dependencyContainer = DependencyContainer()
    let locale = dependencyContainer.deviceHelper.locale
    let paywallCache = PaywallCache(deviceLocaleString: locale)
    let paywallId1 = "id1"
    let key1 = PaywallCacheLogic.key(forIdentifier: paywallId1, locale: locale)

    let paywall1 = dependencyContainer.makePaywallViewController(for: .stub())
    paywall1.cacheKey = key1

    let paywallId2 = "id2"
    let key2 = PaywallCacheLogic.key(forIdentifier: paywallId2, locale: locale)
    let paywall2 = dependencyContainer.makePaywallViewController(for: .stub())
    paywall2.cacheKey = key2

    // When
    PaywallViewController.cache.insert(paywall1)
    PaywallViewController.cache.insert(paywall2)

    let cachedPaywall1 = paywallCache.getPaywallViewController(key: key1)
    let cachedPaywall2 = paywallCache.getPaywallViewController(key: key2)

    XCTAssertEqual(cachedPaywall1, paywall1)
    XCTAssertEqual(cachedPaywall2, paywall2)

    paywallCache.clearCache()

    // Then
    let nilPaywall1 = paywallCache.getPaywallViewController(key: key1)
    let nilPaywall2 = paywallCache.getPaywallViewController(key: key2)

    XCTAssertNil(nilPaywall1)
    XCTAssertNil(nilPaywall2)
  }

  func testViewControllers() {
    // Given
    let dependencyContainer = DependencyContainer()
    let paywall1 = dependencyContainer.makePaywallViewController(for: .stub())
    paywall1.cacheKey = "myid1"
    let paywall2 = dependencyContainer.makePaywallViewController(for: .stub())
    paywall2.cacheKey = "myid2"

    // When
    PaywallViewController.cache.insert(paywall1)
    PaywallViewController.cache.insert(paywall2)

    let viewControllers = PaywallViewController.cache
    XCTAssertTrue(viewControllers.contains(paywall1))
    XCTAssertTrue(viewControllers.contains(paywall2))
  }
}
