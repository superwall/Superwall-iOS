//
//  TestModeAppliedSettings.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 16/10/2026.
//

#if os(macOS)
import Foundation

/// The settings test mode starts with if the modal closes without OK: the saved
/// ones, the defaults once the tester has reset them, or the tester's edits.
final class TestModeAppliedSettings {
  private(set) var selections: [String: EntitlementSelection]
  private(set) var freeTrialOverride: FreeTrialOverride
  private let defaults: UserDefaults
  /// Whether the tester has changed a setting since the modal opened or was reset.
  private var hasEdits = false

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

  /// Takes the tester's latest edits, so closing the modal without OK keeps them.
  func update(
    selections: [String: EntitlementSelection],
    freeTrialOverride: FreeTrialOverride
  ) {
    self.selections = selections
    self.freeTrialOverride = freeTrialOverride
    hasEdits = true
  }

  /// Goes back to the defaults and forgets the saved settings.
  func reset() {
    selections = [:]
    freeTrialOverride = .useDefault
    hasEdits = false
    TestModeSettingsStore.clear(in: defaults)
  }

  /// The settings to start with when the modal closes without OK. Saves any edits
  /// first, as closing the modal does on iOS.
  func closeWithoutOK() -> TestModeModalResult {
    if hasEdits {
      TestModeSettingsStore.save(selections, freeTrialOverride: freeTrialOverride, in: defaults)
    }
    return result
  }
}
#endif
