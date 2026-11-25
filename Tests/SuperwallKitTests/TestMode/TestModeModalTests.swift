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

  private func presentOffscreen(defaults: UserDefaults) async -> TestModeModalResult {
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
      defaults: defaults,
      from: UIViewController()
    )
  }

  @Test
  func present_returnsStartingSettings_whenUIKitRefusesAndNothingSaved() async {
    let isolated = IsolatedDefaults()
    defer { isolated.remove() }

    let result = await presentOffscreen(defaults: isolated.defaults)

    #expect(result.entitlements.isEmpty)
    #expect(result.freeTrialOverride == .forceAvailable)
  }

  @Test
  func present_returnsSavedSettings_whenUIKitRefuses() async {
    let isolated = IsolatedDefaults()
    defer { isolated.remove() }
    isolated.defaults.set(
      ["pro": ["state": LatestSubscription.State.subscribed.rawValue]],
      forKey: Self.settingsKey
    )
    isolated.defaults.set(
      FreeTrialOverride.forceUnavailable.rawValue,
      forKey: Self.freeTrialOverrideKey
    )

    let result = await presentOffscreen(defaults: isolated.defaults)

    #expect(result.entitlements.map(\.id) == ["pro"])
    #expect(result.entitlements.first?.isActive == true)
    #expect(result.freeTrialOverride == .forceUnavailable)
  }

  private func makeModal(defaults: UserDefaults) -> TestModeModalViewController {
    TestModeModalViewController(
      reason: .testModeOption,
      userId: "user",
      isIdentified: false,
      hasPurchaseController: false,
      availableEntitlements: ["pro"],
      initialFreeTrialOverride: .forceUnavailable,
      apiKey: "pk_test",
      networkEnvironment: .release,
      defaults: defaults
    )
  }

  @Test
  func navigationController_reportsClose_whenItLeavesTheScreen() {
    let isolated = IsolatedDefaults()
    defer { isolated.remove() }
    let nav = TestModeNavigationController(rootViewController: makeModal(defaults: isolated.defaults))
    var closeCount = 0
    nav.onClose = { closeCount += 1 }

    // Not in a window, as when the screen below it has been dismissed.
    nav.viewDidDisappear(false)

    #expect(closeCount == 1)
  }

  @Test
  func modal_doesNotReportBack_whenOnlyItsOwnScreenDisappears() {
    // As happens when a detail screen is pushed inside the sheet.
    let isolated = IsolatedDefaults()
    defer { isolated.remove() }
    let modal = makeModal(defaults: isolated.defaults)
    var callCount = 0
    modal.onDismiss = { _, _ in
      callCount += 1
    }

    modal.viewDidDisappear(false)

    #expect(callCount == 0)
  }

  @Test
  func modal_finish_reportsBackOnlyOnce() {
    let isolated = IsolatedDefaults()
    defer { isolated.remove() }
    let modal = makeModal(defaults: isolated.defaults)
    var callCount = 0
    modal.onDismiss = { _, _ in
      callCount += 1
    }

    modal.finish()
    modal.finish()

    #expect(callCount == 1)
  }

  @Test
  func giveUpIfNeverShown_reportsBackOnce_whenTheSheetNeverAppears() async throws {
    let isolated = IsolatedDefaults()
    defer { isolated.remove() }
    let modal = makeModal(defaults: isolated.defaults)
    let nav = TestModeNavigationController(rootViewController: modal)
    var callCount = 0
    modal.onDismiss = { _, _ in
      callCount += 1
    }

    TestModeModal.giveUpIfNeverShown(nav, modal: modal, after: 0)
    try await Task.sleep(nanoseconds: 200_000_000)

    #expect(callCount == 1)
  }

  @Test
  func giveUpIfNeverShown_keepsWaiting_whenTheSheetStartedAppearing() async throws {
    let isolated = IsolatedDefaults()
    defer { isolated.remove() }
    let modal = makeModal(defaults: isolated.defaults)
    let nav = TestModeNavigationController(rootViewController: modal)
    var callCount = 0
    modal.onDismiss = { _, _ in
      callCount += 1
    }

    nav.viewWillAppear(false)
    TestModeModal.giveUpIfNeverShown(nav, modal: modal, after: 0)
    try await Task.sleep(nanoseconds: 200_000_000)

    #expect(callCount == 0)
  }

  @Test
  func modal_closeWithoutOK_savesAndReportsBack() {
    let isolated = IsolatedDefaults()
    defer { isolated.remove() }
    let modal = makeModal(defaults: isolated.defaults)
    modal.selectedFreeTrialOverride = .forceAvailable
    var reported: FreeTrialOverride?
    modal.onDismiss = { _, freeTrialOverride in
      reported = freeTrialOverride
    }

    modal.closeWithoutOK()

    #expect(reported == .forceAvailable)
    #expect(
      isolated.defaults.string(forKey: Self.freeTrialOverrideKey)
        == FreeTrialOverride.forceAvailable.rawValue
    )
  }
}
