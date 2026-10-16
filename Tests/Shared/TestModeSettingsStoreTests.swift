//
//  TestModeSettingsStoreTests.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 13/10/2026.
//
// swiftlint:disable all

@testable import SuperwallKit
import Foundation
import Testing

@Suite
struct TestModeSettingsStoreTests {
  private func makeDefaults() -> UserDefaults {
    let suiteName = "TestModeSettingsStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }

  @Test
  func save_thenLoad_roundTripsSelectionsAndOverride() {
    let defaults = makeDefaults()
    let selections: [String: EntitlementSelection] = [
      "pro": EntitlementSelection(state: .subscribed, offerType: .trial),
      "plus": EntitlementSelection(state: .expired, offerType: nil)
    ]

    TestModeSettingsStore.save(selections, freeTrialOverride: .forceAvailable, in: defaults)

    let loaded = TestModeSettingsStore.loadSelections(from: defaults)
    #expect(loaded["pro"]?.state == .subscribed)
    #expect(loaded["pro"]?.offerType == .trial)
    #expect(loaded["plus"]?.state == .expired)
    #expect(loaded["plus"]?.offerType == nil)
    #expect(
      TestModeSettingsStore.loadFreeTrialOverride(from: defaults, fallback: .useDefault) == .forceAvailable
    )
  }

  @Test
  func save_dropsSelectionsWithNothingChosen() {
    let defaults = makeDefaults()
    TestModeSettingsStore.save(
      ["pro": EntitlementSelection(state: nil, offerType: nil)],
      freeTrialOverride: .useDefault,
      in: defaults
    )

    #expect(TestModeSettingsStore.loadSelections(from: defaults).isEmpty)
  }

  @Test
  func loadFreeTrialOverride_fallsBack_whenNothingSaved() {
    let defaults = makeDefaults()
    #expect(
      TestModeSettingsStore.loadFreeTrialOverride(from: defaults, fallback: .forceUnavailable) == .forceUnavailable
    )
  }

  @Test
  func clear_removesEverythingSaved() {
    let defaults = makeDefaults()
    TestModeSettingsStore.save(
      ["pro": EntitlementSelection(state: .subscribed, offerType: nil)],
      freeTrialOverride: .forceAvailable,
      in: defaults
    )

    TestModeSettingsStore.clear(in: defaults)

    #expect(TestModeSettingsStore.loadSelections(from: defaults).isEmpty)
    #expect(
      TestModeSettingsStore.loadFreeTrialOverride(from: defaults, fallback: .useDefault) == .useDefault
    )
  }

  @Test
  func entitlements_areActiveOnlyForPayingStates() {
    let entitlements = TestModeSettingsStore.entitlements(from: [
      "subscribed": EntitlementSelection(state: .subscribed, offerType: nil),
      "grace": EntitlementSelection(state: .inGracePeriod, offerType: nil),
      "retry": EntitlementSelection(state: .inBillingRetryPeriod, offerType: nil),
      "expired": EntitlementSelection(state: .expired, offerType: nil),
      "revoked": EntitlementSelection(state: .revoked, offerType: nil),
      "inactive": EntitlementSelection(state: nil, offerType: nil)
    ])

    let activeIds = Set(entitlements.filter { $0.isActive }.map { $0.id })
    let inactiveIds = Set(entitlements.filter { !$0.isActive }.map { $0.id })
    #expect(activeIds == ["subscribed", "grace", "retry"])
    #expect(inactiveIds == ["expired", "revoked"])
  }

  @Test
  func entitlements_keepTheOfferType() {
    let entitlements = TestModeSettingsStore.entitlements(from: [
      "pro": EntitlementSelection(state: .subscribed, offerType: .promotional)
    ])

    #expect(entitlements.first?.offerType == .promotional)
    #expect(entitlements.first?.store == .appStore)
  }
}
