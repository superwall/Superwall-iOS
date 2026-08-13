//
//  RefreshFreeTrialAvailabilityTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 13/08/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Tests for the per-product free trial availability map calculated by
/// `PaywallRequestManager.refreshFreeTrialAvailability`.
///
/// These tests deliberately avoid paths that read `Superwall.shared.customerInfo`
/// or live StoreKit state, exercising the map population, developer override
/// gating, and paywall-level flag instead.
struct RefreshFreeTrialAvailabilityTests {
  private func makeRequest(
    _ dependencyContainer: DependencyContainer,
    isFreeTrialOverride: Bool? = nil
  ) -> PaywallRequest {
    return dependencyContainer.makePaywallRequest(
      responseIdentifiers: .none,
      overrides: .init(isFreeTrial: isFreeTrialOverride),
      isDebuggerLaunched: false,
      presentationSourceType: nil
    )
  }

  // MARK: - Map Population

  @Test
  func unloadedAppStoreProducts_populateMapWithFalse() async {
    let dependencyContainer = DependencyContainer()
    let paywall: Paywall = .stub()
      .setting(\.products, to: [
        SuperwallKit.Product(
          name: "primary",
          type: .appStore(.init(id: "com.a.monthly")),
          id: "com.a.monthly",
          entitlements: []
        ),
        SuperwallKit.Product(
          name: "secondary",
          type: .appStore(.init(id: "com.b.monthly")),
          id: "com.b.monthly",
          entitlements: []
        )
      ])
    let request = makeRequest(dependencyContainer)

    let result = await dependencyContainer.paywallRequestManager.refreshFreeTrialAvailability(
      for: paywall,
      request: request
    )

    // No StoreProducts are cached, so neither product can offer a trial.
    #expect(result.isFreeTrialAvailableByProductName == ["primary": false, "secondary": false])
    #expect(!result.isFreeTrialAvailable)
  }

  @Test
  func unnamedProducts_areOmittedFromMap() async {
    let dependencyContainer = DependencyContainer()
    let paywall: Paywall = .stub()
      .setting(\.products, to: [
        SuperwallKit.Product(
          name: nil,
          type: .appStore(.init(id: "com.a.monthly")),
          id: "com.a.monthly",
          entitlements: []
        )
      ])
    let request = makeRequest(dependencyContainer)

    let result = await dependencyContainer.paywallRequestManager.refreshFreeTrialAvailability(
      for: paywall,
      request: request
    )

    #expect(result.isFreeTrialAvailableByProductName.isEmpty)
  }

  @Test
  func stripeProduct_withoutEntitlements_isNotAvailable() async {
    let dependencyContainer = DependencyContainer()
    let paywall: Paywall = .stub()
      .setting(\.products, to: [
        SuperwallKit.Product(
          name: "primary",
          type: .stripe(.init(id: "stripe_1", trialDays: 7)),
          id: "stripe_1",
          entitlements: []
        )
      ])
    let request = makeRequest(dependencyContainer)

    let result = await dependencyContainer.paywallRequestManager.refreshFreeTrialAvailability(
      for: paywall,
      request: request
    )

    // Trial days are set but there's no entitlement to check history against.
    #expect(result.isFreeTrialAvailableByProductName == ["primary": false])
    #expect(!result.isFreeTrialAvailable)
  }

  // MARK: - Developer Override

  @Test
  func devOverrideTrue_forcesPaywallFlag_andGatesPerProductByIntroOffer() async {
    let dependencyContainer = DependencyContainer()
    let paywall: Paywall = .stub()
      .setting(\.products, to: [
        SuperwallKit.Product(
          name: "primary",
          type: .stripe(.init(id: "stripe_1", trialDays: 7)),
          id: "stripe_1",
          entitlements: [.stub()]
        ),
        SuperwallKit.Product(
          name: "secondary",
          type: .appStore(.init(id: "com.a.monthly")),
          id: "com.a.monthly",
          entitlements: []
        )
      ])
    let request = makeRequest(dependencyContainer, isFreeTrialOverride: true)

    let result = await dependencyContainer.paywallRequestManager.refreshFreeTrialAvailability(
      for: paywall,
      request: request
    )

    // The paywall-level flag takes the forced value verbatim. Per-product
    // values stay gated by whether the product can offer a trial at all:
    // the Stripe product has trial days, the App Store product isn't loaded.
    #expect(result.isFreeTrialAvailable)
    #expect(result.isFreeTrialAvailableByProductName == ["primary": true, "secondary": false])
  }

  @Test
  func devOverrideTrue_stripeProductWithoutTrialDays_staysFalse() async {
    let dependencyContainer = DependencyContainer()
    let paywall: Paywall = .stub()
      .setting(\.products, to: [
        SuperwallKit.Product(
          name: "primary",
          type: .stripe(.init(id: "stripe_1", trialDays: nil)),
          id: "stripe_1",
          entitlements: [.stub()]
        )
      ])
    let request = makeRequest(dependencyContainer, isFreeTrialOverride: true)

    let result = await dependencyContainer.paywallRequestManager.refreshFreeTrialAvailability(
      for: paywall,
      request: request
    )

    #expect(result.isFreeTrialAvailable)
    #expect(result.isFreeTrialAvailableByProductName == ["primary": false])
  }

  @Test
  func devOverrideFalse_forcesEverythingFalse() async {
    let dependencyContainer = DependencyContainer()
    let paywall: Paywall = .stub()
      .setting(\.products, to: [
        SuperwallKit.Product(
          name: "primary",
          type: .stripe(.init(id: "stripe_1", trialDays: 7)),
          id: "stripe_1",
          entitlements: [.stub()]
        )
      ])
    let request = makeRequest(dependencyContainer, isFreeTrialOverride: false)

    let result = await dependencyContainer.paywallRequestManager.refreshFreeTrialAvailability(
      for: paywall,
      request: request
    )

    #expect(!result.isFreeTrialAvailable)
    #expect(result.isFreeTrialAvailableByProductName == ["primary": false])
  }

  // MARK: - Cached Paywall Propagation

  @Test
  func updateFrom_propagatesPerProductAvailability() {
    var cached: Paywall = .stub()
    let fresh: Paywall = .stub()
      .setting(\.isFreeTrialAvailable, to: true)
      .setting(\.isFreeTrialAvailableByProductName, to: ["primary": true, "secondary": false])

    cached.update(from: fresh)

    #expect(cached.isFreeTrialAvailable)
    #expect(cached.isFreeTrialAvailableByProductName == ["primary": true, "secondary": false])
  }
}
