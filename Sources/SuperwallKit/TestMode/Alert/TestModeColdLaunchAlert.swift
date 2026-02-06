//
//  TestModeColdLaunchAlert.swift
//  Superwall
//
//  Created by Claude on 2026-01-27.
//

import UIKit

/// Result from the test mode cold launch alert.
struct TestModeAlertResult {
  /// The selected entitlements with their states.
  let entitlements: Set<Entitlement>

  /// The selected free trial override setting.
  let freeTrialOverride: FreeTrialOverride
}

/// Presents the test mode cold launch alert when a user is first detected as being in test mode.
enum TestModeColdLaunchAlert {
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
  ) async -> TestModeAlertResult {
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
        continuation.resume(returning: TestModeAlertResult(
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
