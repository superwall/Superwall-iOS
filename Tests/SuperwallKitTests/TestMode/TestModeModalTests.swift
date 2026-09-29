//
//  TestModeModalTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 2026-09-29.
//
// swiftlint:disable all

@testable import SuperwallKit
import Testing
import UIKit

@Suite(.serialized)
@MainActor
struct TestModeModalTests {
  private final class StubViewController: UIViewController {
    var stubPresented: UIViewController?
    var stubIsBeingDismissed = false

    override var presentedViewController: UIViewController? { stubPresented }
    override var isBeingDismissed: Bool { stubIsBeingDismissed }
  }

  @Test
  func topPresenter_returnsSelf_whenNothingPresented() {
    let root = StubViewController()
    #expect(TestModeModal.topPresenter(from: root) === root)
  }

  @Test
  func topPresenter_walksUpToTheSheetOnTop() {
    let root = StubViewController()
    let sheet = StubViewController()
    let nested = StubViewController()
    root.stubPresented = sheet
    sheet.stubPresented = nested

    #expect(TestModeModal.topPresenter(from: root) === nested)
  }

  @Test
  func topPresenter_skipsASheetThatIsClosing() {
    let root = StubViewController()
    let closing = StubViewController()
    closing.stubIsBeingDismissed = true
    root.stubPresented = closing

    #expect(TestModeModal.topPresenter(from: root) === root)
  }

  private static let settingsKey = "com.superwall.testmode.entitlementSettings"
  private static let freeTrialOverrideKey = "com.superwall.testmode.freeTrialOverride"

  private func clearSavedSettings() {
    UserDefaults.standard.removeObject(forKey: Self.settingsKey)
    UserDefaults.standard.removeObject(forKey: Self.freeTrialOverrideKey)
  }

  private func presentOffscreen() async -> TestModeModalResult {
    // Not in a window, so UIKit refuses the presentation.
    await TestModeModal.present(
      reason: .testModeOption,
      userId: "user",
      isIdentified: false,
      hasPurchaseController: false,
      availableEntitlements: ["pro"],
      initialFreeTrialOverride: .forceAvailable,
      apiKey: "pk_test",
      networkEnvironment: .release,
      from: UIViewController()
    )
  }

  @Test
  func present_returnsStartingSettings_whenUIKitRefusesAndNothingSaved() async {
    clearSavedSettings()
    defer { clearSavedSettings() }

    let result = await presentOffscreen()

    #expect(result.entitlements.isEmpty)
    #expect(result.freeTrialOverride == .forceAvailable)
  }

  @Test
  func present_returnsSavedSettings_whenUIKitRefuses() async {
    clearSavedSettings()
    defer { clearSavedSettings() }
    UserDefaults.standard.set(
      ["pro": ["state": LatestSubscription.State.subscribed.rawValue]],
      forKey: Self.settingsKey
    )
    UserDefaults.standard.set(
      FreeTrialOverride.forceUnavailable.rawValue,
      forKey: Self.freeTrialOverrideKey
    )

    let result = await presentOffscreen()

    #expect(result.entitlements.map(\.id) == ["pro"])
    #expect(result.entitlements.first?.isActive == true)
    #expect(result.freeTrialOverride == .forceUnavailable)
  }

  private func makeModal() -> TestModeModalViewController {
    TestModeModalViewController(
      reason: .testModeOption,
      userId: "user",
      isIdentified: false,
      hasPurchaseController: false,
      availableEntitlements: ["pro"],
      initialFreeTrialOverride: .forceUnavailable,
      apiKey: "pk_test",
      networkEnvironment: .release
    )
  }

  @Test
  func navigationController_reportsClose_whenItLeavesTheScreen() {
    let nav = TestModeNavigationController(rootViewController: makeModal())
    var closeCount = 0
    nav.onClose = { closeCount += 1 }

    // Not in a window, as when the screen below it has been dismissed.
    nav.viewDidDisappear(false)

    #expect(closeCount == 1)
  }

  @Test
  func modal_doesNotReportBack_whenOnlyItsOwnScreenDisappears() {
    // As happens when a detail screen is pushed inside the sheet.
    let modal = makeModal()
    var callCount = 0
    modal.onDismiss = { _, _ in
      callCount += 1
    }

    modal.viewDidDisappear(false)

    #expect(callCount == 0)
  }

  @Test
  func modal_finish_reportsBackOnlyOnce() {
    let modal = makeModal()
    var callCount = 0
    modal.onDismiss = { _, _ in
      callCount += 1
    }

    modal.finish()
    modal.finish()

    #expect(callCount == 1)
  }
}
