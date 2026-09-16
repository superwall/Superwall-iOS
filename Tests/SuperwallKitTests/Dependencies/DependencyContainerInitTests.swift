//
//  DependencyContainerInitTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 25/08/2026.
//

import Testing
@testable import SuperwallKit
import Foundation

struct DependencyContainerInitTests {
  /// https://github.com/superwall/Superwall-iOS/issues/504
  ///
  /// `DependencyContainer.init` used to pass `self` to `WebEntitlementRedeemer`,
  /// whose init spawned a task reading `configManager` on a background thread
  /// while init was still assigning stored properties. This loop only signals
  /// under Thread Sanitizer (`-enableThreadSanitizer YES`), where it reproduced
  /// the race on the first iteration; without TSan it's a smoke test.
  @Test("Constructing the container doesn't race against its own init")
  func containerInitHasNoDataRace() {
    for _ in 0..<10 {
      _ = DependencyContainer(apiKey: "pk_test_504")
    }
  }
}

/// The purchases read only ever adds App Store history, so callers ask this
/// before deciding whether an entitlement's answer can change when it lands.
@Suite(.serialized)
struct AppStoreEntitlementLookupTests {
  private func makeProduct(
    id: String,
    entitlementId: String,
    isAppStore: Bool
  ) -> SuperwallKit.Product {
    return SuperwallKit.Product(
      name: id,
      type: isAppStore ? .appStore(.init(id: id)) : .stripe(.init(id: id, trialDays: nil)),
      id: id,
      entitlements: [Entitlement(id: entitlementId)]
    )
  }

  @Test("Only App Store products put an entitlement within the read's reach")
  func onlyAppStoreProductsCount() {
    let container = DependencyContainer()
    let config: Config = .stub()
      .setting(
        \.products,
        to: [
          makeProduct(id: "com.app.pro", entitlementId: "pro", isAppStore: true),
          makeProduct(id: "com.app.web", entitlementId: "web_only", isAppStore: false)
        ]
      )
    container.configManager.configState.send(.retrieved(config))

    #expect(container.purchasesLoadCouldChange(entitlementIds: ["pro"]))
    #expect(container.purchasesLoadCouldChange(entitlementIds: ["web_only"]) == false)
    // A web product sharing an entitlement with an App Store one still waits.
    #expect(container.purchasesLoadCouldChange(entitlementIds: ["web_only", "pro"]))
    #expect(container.purchasesLoadCouldChange(entitlementIds: []) == false)
  }

  @Test("Without config the load can't be ruled out, so callers wait")
  func waitsWhenConfigIsMissing() {
    let container = DependencyContainer()
    #expect(container.configManager.config == nil)
    #expect(container.purchasesLoadCouldChange(entitlementIds: ["pro"]))
  }

  @Test("A granted entitlement is in reach even when only a web product sells it")
  func grantedEntitlementIsInReach() {
    let container = DependencyContainer()
    let config: Config = .stub()
      .setting(
        \.products,
        to: [makeProduct(id: "com.app.web", entitlementId: "web_only", isAppStore: false)]
      )
    container.configManager.configState.send(.retrieved(config))
    #expect(container.purchasesLoadCouldChange(entitlementIds: ["web_only"]) == false)

    // The grant refresh skips purchase-controller apps, so the load is the only
    // thing that would bring this into `customerInfo` for them.
    container.entitlementsInfo.setGranted([Entitlement(id: "web_only")])
    defer { container.entitlementsInfo.setGranted([]) }
    #expect(container.purchasesLoadCouldChange(entitlementIds: ["web_only"]))
  }
}
