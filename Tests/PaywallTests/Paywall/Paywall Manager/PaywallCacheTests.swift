//
//  PaywallCacheTests.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//

// swiftlint:disable all

import XCTest
@testable import Paywall

class PaywallCacheTests: XCTestCase {
  let paywallCache = PaywallCache()

  override func setUp() {
    paywallCache.clearCache()
  }

  func testSaveAndRetrievePaywall() throws {
    // Given
    let paywall: SWPaywallViewController = .stub()
    let id = "myid"

    // When
    paywallCache.savePaywall(
      paywall,
      withIdentifier: id,
      forEvent: nil
    )

    let key = PaywallCacheLogic.key(
      forIdentifier: id,
      event: nil
    )

    let cachedPaywall = paywallCache.getPaywall(withKey: key)

    // Then
    XCTAssertEqual(cachedPaywall, paywall)
  }

  func testSaveAndRemovePaywall_withId() {
    // Given
    let paywall: SWPaywallViewController = .stub()
    let id = "myid"

    // When
    paywallCache.savePaywall(
      paywall,
      withIdentifier: id,
      forEvent: nil
    )

    let key = PaywallCacheLogic.key(
      forIdentifier: id,
      event: nil
    )

    var cachedPaywall = paywallCache.getPaywall(withKey: key)

    XCTAssertEqual(cachedPaywall, paywall)

    paywallCache.removePaywall(
      withIdentifier: id,
      forEvent: nil
    )

    // Then
    cachedPaywall = paywallCache.getPaywall(withKey: key)

    XCTAssertNil(cachedPaywall)
  }

  func testSaveAndRemovePaywall_withVc() {
    // Given
    let paywall: SWPaywallViewController = .stub()

    // When
    paywallCache.savePaywall(
      paywall,
      withIdentifier: nil,
      forEvent: nil
    )

    let key = PaywallCacheLogic.key(
      forIdentifier: nil,
      event: nil
    )

    var cachedPaywall = paywallCache.getPaywall(withKey: key)

    XCTAssertEqual(cachedPaywall, paywall)


    paywallCache.removePaywall(withViewController: paywall)

    // Then
    cachedPaywall = paywallCache.getPaywall(withKey: key)

    XCTAssertNil(cachedPaywall)
  }

  func testClearCache() {
    // Given
    let paywall1: SWPaywallViewController = .stub()
    let paywallId1 = "id1"
    let paywall2: SWPaywallViewController = .stub()
    let paywallId2 = "id2"

    // When
    paywallCache.savePaywall(
      paywall1,
      withIdentifier: paywallId1,
      forEvent: nil
    )

    let key1 = PaywallCacheLogic.key(
      forIdentifier: paywallId1,
      event: nil
    )

    paywallCache.savePaywall(
      paywall2,
      withIdentifier: paywallId2,
      forEvent: nil
    )

    let key2 = PaywallCacheLogic.key(
      forIdentifier: paywallId2,
      event: nil
    )

    let cachedPaywall1 = paywallCache.getPaywall(withKey: key1)
    let cachedPaywall2 = paywallCache.getPaywall(withKey: key2)

    XCTAssertEqual(cachedPaywall1, paywall1)
    XCTAssertEqual(cachedPaywall2, paywall2)

    paywallCache.clearCache()

    // Then
    let nilPaywall1 = paywallCache.getPaywall(withKey: key1)
    let nilPaywall2 = paywallCache.getPaywall(withKey: key2)

    XCTAssertNil(nilPaywall1)
    XCTAssertNil(nilPaywall2)
  }

  func testViewControllers() {
    // Given
    let paywall1: SWPaywallViewController = .stub()
    let paywallId1 = "myid1"
    let paywall2: SWPaywallViewController = .stub()
    let paywallId2 = "myid2"

    // When
    paywallCache.savePaywall(
      paywall1,
      withIdentifier: paywallId1,
      forEvent: nil
    )

    paywallCache.savePaywall(
      paywall2,
      withIdentifier: paywallId2,
      forEvent: nil
    )

    let viewControllers = Set(paywallCache.viewControllers)
    XCTAssertTrue(viewControllers.contains(paywall1))
    XCTAssertTrue(viewControllers.contains(paywall2))
  }
}
