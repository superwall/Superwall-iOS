//
//  TestModeAppliedSettings.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 16/10/2026.
//

#if os(macOS)
import Foundation

/// The settings test mode starts with if the modal closes without OK: the saved
/// ones, or the defaults once the tester has reset them.
final class TestModeAppliedSettings {
  private(set) var selections: [String: EntitlementSelection]
  private(set) var freeTrialOverride: FreeTrialOverride
  private let defaults: UserDefaults

  init(
    selections: [String: EntitlementSelection],
    freeTrialOverride: FreeTrialOverride,
    defaults: UserDefaults = .standard
  ) {
    self.selections = selections
    self.freeTrialOverride = freeTrialOverride
    self.defaults = defaults
  }

  var result: TestModeModalResult {
    return TestModeModalResult(
      entitlements: TestModeSettingsStore.entitlements(from: selections),
      freeTrialOverride: freeTrialOverride
    )
  }

  /// Goes back to the defaults and forgets the saved settings.
  func reset() {
    selections = [:]
    freeTrialOverride = .useDefault
    TestModeSettingsStore.clear(in: defaults)
  }
}
#endif
