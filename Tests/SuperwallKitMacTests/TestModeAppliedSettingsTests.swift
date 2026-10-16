// swiftlint:disable all
#if os(macOS)
import Foundation
import Testing
@testable import SuperwallKit

@Suite
struct TestModeAppliedSettingsTests {
  private func makeDefaults() -> UserDefaults {
    let suiteName = "TestModeAppliedSettingsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }

  @Test
  func closingWithoutOKKeepsTheSavedSettings() {
    let selections = ["pro": EntitlementSelection(state: .subscribed, offerType: nil)]
    let settings = TestModeAppliedSettings(
      selections: selections,
      freeTrialOverride: .forceAvailable,
      defaults: makeDefaults()
    )

    #expect(settings.result.entitlements.map(\.id) == ["pro"])
    #expect(settings.result.freeTrialOverride == .forceAvailable)
  }

  @Test
  func closingAfterResetUsesTheDefaults() {
    let defaults = makeDefaults()
    let selections = ["pro": EntitlementSelection(state: .subscribed, offerType: nil)]
    TestModeSettingsStore.save(selections, freeTrialOverride: .forceAvailable, in: defaults)
    let settings = TestModeAppliedSettings(
      selections: selections,
      freeTrialOverride: .forceAvailable,
      defaults: defaults
    )

    settings.reset()

    #expect(settings.result.entitlements.isEmpty)
    #expect(settings.result.freeTrialOverride == .useDefault)
    #expect(TestModeSettingsStore.loadSelections(from: defaults).isEmpty)
  }
}
#endif
