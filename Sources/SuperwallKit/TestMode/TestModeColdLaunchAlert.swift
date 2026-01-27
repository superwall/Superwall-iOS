//
//  TestModeColdLaunchAlert.swift
//  Superwall
//
//  Created by Claude on 2026-01-27.
//

import UIKit

/// Presents the test mode cold launch alert when a user is first detected as being in test mode.
enum TestModeColdLaunchAlert {
  @MainActor
  static func present(
    reason: TestModeReason,
    userId: String,
    hasPurchaseController: Bool,
    from viewController: UIViewController
  ) {
    var message = """
    \(reason.description)

    User ID: \(userId)
    """

    if hasPurchaseController {
      message += "\n\n⚠️ Purchase controller is not used in Test Mode. All purchases are simulated by Superwall."
    }

    message += "\n\nAll purchases will be simulated — no real transactions will occur."

    let alert = UIAlertController(
      title: "🧪 Test Mode Active",
      message: message,
      preferredStyle: .alert
    )

    let copyAction = UIAlertAction(title: "Copy User ID", style: .default) { _ in
      UIPasteboard.general.string = userId
    }
    alert.addAction(copyAction)

    let dismissAction = UIAlertAction(title: "OK", style: .cancel)
    alert.addAction(dismissAction)

    viewController.present(alert, animated: true)
  }
}
