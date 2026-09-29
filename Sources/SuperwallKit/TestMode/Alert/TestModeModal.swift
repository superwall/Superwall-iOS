//
//  TestModeModal.swift
//  Superwall
//
//  Created by Claude on 2026-01-27.
//

import UIKit

/// Result from the test mode modal.
struct TestModeModalResult {
  /// The selected entitlements with their states.
  let entitlements: Set<Entitlement>

  /// The selected free trial override setting.
  let freeTrialOverride: FreeTrialOverride
}

/// Presents the test mode modal when a user is first detected as being in test mode.
enum TestModeModal {
  @MainActor
  static func present(
    reason: TestModeReason,
    userId: String,
    isIdentified: Bool,
    hasPurchaseController: Bool,
    availableEntitlements: [String],
    initialFreeTrialOverride: FreeTrialOverride,
    apiKey: String,
    networkEnvironment: SuperwallOptions.NetworkEnvironment,
    from viewController: UIViewController
  ) async -> TestModeModalResult {
    await withCheckedContinuation { continuation in
      let modal = TestModeModalViewController(
        reason: reason,
        userId: userId,
        isIdentified: isIdentified,
        hasPurchaseController: hasPurchaseController,
        availableEntitlements: availableEntitlements,
        initialFreeTrialOverride: initialFreeTrialOverride,
        apiKey: apiKey,
        networkEnvironment: networkEnvironment
      )
      modal.onDismiss = { entitlements, freeTrialOverride in
        continuation.resume(returning: TestModeModalResult(
          entitlements: entitlements,
          freeTrialOverride: freeTrialOverride
        ))
      }

      let navController = TestModeNavigationController(rootViewController: modal)
      navController.onClose = { [weak modal] in
        modal?.closeWithoutOK()
      }
      navController.navigationBar.isHidden = true
      navController.modalPresentationStyle = .pageSheet

      let presenter = topPresenter(from: viewController)
      presenter.present(navController, animated: true)

      // UIKit silently refuses when the presenter is already showing
      // something, which would leave this waiting forever. Fall back to the
      // tester's saved choices so config can still finish loading.
      if navController.presentingViewController == nil {
        Logger.debug(
          logLevel: .warn,
          scope: .superwallCore,
          message: "Couldn't show the test mode sheet, so using the saved test mode settings."
        )
        modal.finish()
      }
    }
  }

  /// Walks up from `viewController` to the screen on top, skipping any that
  /// are on their way out, so the modal can sit above sheets like the
  /// Customer Center.
  static func topPresenter(from viewController: UIViewController) -> UIViewController {
    var presenter = viewController
    while let presented = presenter.presentedViewController,
      !presented.isBeingDismissed {
      presenter = presented
    }
    return presenter
  }
}

/// Reports when the whole sheet closes, including when the screen below it is
/// dismissed and takes the sheet with it without OK being tapped. Pushing a
/// detail screen inside the sheet doesn't count.
final class TestModeNavigationController: UINavigationController {
  var onClose: (() -> Void)?

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    // Still around if it's only covered by something presented on top.
    if view.window != nil || presentedViewController != nil {
      return
    }
    onClose?()
  }
}

extension TestModeModalViewController {
  /// Hands back the selections, at most once.
  func finish() {
    let onDismiss = self.onDismiss
    self.onDismiss = nil
    onDismiss?(buildEntitlements(), selectedFreeTrialOverride)
  }

  /// Saves and hands back the selections as OK would, for when the sheet
  /// closes some other way.
  func closeWithoutOK() {
    saveSettings()
    finish()
  }
}
