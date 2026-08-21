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

      let navController = UINavigationController(rootViewController: modal)
      navController.navigationBar.isHidden = true
      navController.modalPresentationStyle = .pageSheet

      viewController.present(navController, animated: true)
    }
  }
}
