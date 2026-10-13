//
//  TestModeSettingsStore.swift
//  SuperwallKit
//
//  Created by Brian Anglin on 13/10/2026.
//

import Foundation

/// The tester's choices in the test mode modal: the state of each entitlement
/// and the free trial override, kept between launches.
///
/// Shared by the UIKit and AppKit modals so both read and write the same
/// settings, and turn them into the same entitlements.
enum TestModeSettingsStore {
  static let settingsKey = "com.superwall.testmode.entitlementSettings"
  static let freeTrialOverrideKey = "com.superwall.testmode.freeTrialOverride"

  static func save(
    _ selections: [String: EntitlementSelection],
    freeTrialOverride: FreeTrialOverride,
    in defaults: UserDefaults = .standard
  ) {
    var settingsToSave: [String: [String: String]] = [:]
    for (entitlementId, selection) in selections {
      var selectionDict: [String: String] = [:]
      if let state = selection.state {
        selectionDict["state"] = state.rawValue
      }
      if let offerType = selection.offerType {
        selectionDict["offerType"] = offerType.rawValue
      }
      if !selectionDict.isEmpty {
        settingsToSave[entitlementId] = selectionDict
      }
    }
    defaults.set(settingsToSave, forKey: settingsKey)
    defaults.set(freeTrialOverride.rawValue, forKey: freeTrialOverrideKey)
  }

  static func loadSelections(from defaults: UserDefaults = .standard) -> [String: EntitlementSelection] {
    guard let savedDict = defaults.dictionary(
      forKey: settingsKey
    ) as? [String: [String: String]] else {
      return [:]
    }

    var result: [String: EntitlementSelection] = [:]
    for (entitlementId, selectionDict) in savedDict {
      var state: LatestSubscription.State?
      var offerType: LatestSubscription.OfferType?

      if let stateRaw = selectionDict["state"] {
        state = LatestSubscription.State(rawValue: stateRaw)
      }
      if let offerTypeRaw = selectionDict["offerType"] {
        offerType = LatestSubscription.OfferType(rawValue: offerTypeRaw)
      }

      result[entitlementId] = EntitlementSelection(state: state, offerType: offerType)
    }
    return result
  }

  /// The saved override, or `fallback` when none has been saved.
  static func loadFreeTrialOverride(
    from defaults: UserDefaults = .standard,
    fallback: FreeTrialOverride
  ) -> FreeTrialOverride {
    guard
      let savedOverrideRaw = defaults.string(forKey: freeTrialOverrideKey),
      let savedOverride = FreeTrialOverride(rawValue: savedOverrideRaw)
    else {
      return fallback
    }
    return savedOverride
  }

  static func clear(in defaults: UserDefaults = .standard) {
    defaults.removeObject(forKey: settingsKey)
    defaults.removeObject(forKey: freeTrialOverrideKey)
  }

  /// The entitlements the selections describe. One left inactive isn't included.
  static func entitlements(from selections: [String: EntitlementSelection]) -> Set<Entitlement> {
    var entitlements: Set<Entitlement> = []
    for (entitlementId, selection) in selections {
      guard let state = selection.state else { continue }
      let isActive = state == .subscribed || state == .inGracePeriod || state == .inBillingRetryPeriod
      let entitlement = Entitlement(
        id: entitlementId,
        type: .serviceLevel,
        isActive: isActive,
        store: .appStore,
        state: state,
        offerType: selection.offerType
      )
      entitlements.insert(entitlement)
    }
    return entitlements
  }
}
