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

  @Test
  func present_returnsStartingSettings_whenUIKitRefusesToPresent() async {
    // Not in a window, so UIKit refuses the presentation.
    let offscreen = UIViewController()

    let result = await TestModeModal.present(
      reason: .testModeOption,
      userId: "user",
      isIdentified: false,
      hasPurchaseController: false,
      availableEntitlements: ["pro"],
      initialFreeTrialOverride: .forceAvailable,
      apiKey: "pk_test",
      networkEnvironment: .release,
      from: offscreen
    )

    #expect(result.entitlements.isEmpty)
    #expect(result.freeTrialOverride == .forceAvailable)
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
  func modal_reportsBackOnce_whenItLeavesTheScreenWithoutOK() {
    let modal = makeModal()
    modal.selectedFreeTrialOverride = .forceUnavailable
    var calls: [FreeTrialOverride] = []
    modal.onDismiss = { _, freeTrialOverride in
      calls.append(freeTrialOverride)
    }

    // Not in a window, as when the screen below it has been dismissed.
    modal.viewDidDisappear(false)
    modal.viewDidDisappear(false)

    #expect(calls == [.forceUnavailable])
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
