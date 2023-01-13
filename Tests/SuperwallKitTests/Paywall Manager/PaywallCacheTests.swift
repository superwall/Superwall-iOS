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
  let paywallCache = PaywallCache(deviceLocaleString: "en_GB")

  override func setUp() {
    paywallCache.clearCache()
  }

  func testSaveAndRetrievePaywall() throws {
    // Given
    let id = "myid"
    let key = PaywallCacheLogic.key(forIdentifier: id, locale: "gb")
    let dependencyContainer = DependencyContainer(apiKey: "abc")
    let paywall = dependencyContainer.makePaywallViewController(for: .stub())
    paywall.cacheKey = key

    // When
    PaywallViewController.cache.insert(paywall)

    let cachedPaywall = paywallCache.getPaywall(withKey: key)

    // Then
    XCTAssertEqual(cachedPaywall, paywall)
  }

  func testSaveAndRemovePaywall_withId() {
    // Given
    let id = "myid"
    let key = PaywallCacheLogic.key(forIdentifier: id, locale: "en")
    let dependencyContainer = DependencyContainer(apiKey: "abc")
    let paywall = dependencyContainer.makePaywallViewController(for: .stub())
    paywall.cacheKey = key

    // When
    PaywallViewController.cache.insert(paywall)

    var cachedPaywall = paywallCache.getPaywall(withKey: key)

    XCTAssertEqual(cachedPaywall, paywall)

    paywallCache.removePaywall(
      withIdentifier: id
    )

    // Then
    cachedPaywall = paywallCache.getPaywall(withKey: key)

    XCTAssertNil(cachedPaywall)
  }

  func testSaveAndRemovePaywall_withVc() {
    // Given
    let dependencyContainer = DependencyContainer(apiKey: "abc")
    let paywallVc = dependencyContainer.makePaywallViewController(for: .stub())

    // When
    PaywallViewController.cache.insert(paywallVc)

    let key = PaywallCacheLogic.key(
      forIdentifier: paywallVc.paywall.identifier,
      locale: "en_GB"
    )

    var cachedPaywallVc = paywallCache.getPaywall(withKey: key)

    XCTAssertEqual(cachedPaywallVc, paywallVc)

    paywallCache.removePaywall(withViewController: paywallVc)

    // Then
    cachedPaywallVc = paywallCache.getPaywall(withKey: key)

    XCTAssertNil(cachedPaywallVc)
  }

  func testClearCache() {
    // Given
    let paywallId1 = "id1"
    let key1 = PaywallCacheLogic.key(forIdentifier: paywallId1, locale: "en_GB")

    let dependencyContainer = DependencyContainer(apiKey: "abc")
    let paywall1 = dependencyContainer.makePaywallViewController(for: .stub())
    paywall1.cacheKey = key1

    let paywallId2 = "id2"
    let key2 = PaywallCacheLogic.key(forIdentifier: paywallId2, locale: "en_GB")
    let paywall2 = dependencyContainer.makePaywallViewController(for: .stub())
    paywall2.cacheKey = key2

    // When
    PaywallViewController.cache.insert(paywall1)
    PaywallViewController.cache.insert(paywall2)

    let cachedPaywall1 = self.paywallCache.getPaywall(withKey: key1)
    let cachedPaywall2 = self.paywallCache.getPaywall(withKey: key2)

    XCTAssertEqual(cachedPaywall1, paywall1)
    XCTAssertEqual(cachedPaywall2, paywall2)

    self.paywallCache.clearCache()

    // Then
    let nilPaywall1 = self.paywallCache.getPaywall(withKey: key1)
    let nilPaywall2 = self.paywallCache.getPaywall(withKey: key2)

    XCTAssertNil(nilPaywall1)
    XCTAssertNil(nilPaywall2)
  }

  func testViewControllers() {
    // Given
    let dependencyContainer = DependencyContainer(apiKey: "abc")
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
