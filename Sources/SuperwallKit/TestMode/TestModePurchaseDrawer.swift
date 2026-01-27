//
//  TestModePurchaseDrawer.swift
//  Superwall
//
//  Created by Claude on 2026-01-27.
//

import UIKit

/// The result of a test mode purchase interaction.
enum TestModePurchaseResult {
  /// User chose to simulate a successful purchase.
  case purchased
  /// User chose to abandon the purchase.
  case abandoned
  /// User chose to simulate a purchase failure.
  case failed
}

/// Presents a bottom sheet for test mode purchases instead of calling StoreKit.
///
/// Shows three options: Purchase, Abandon, Failure — each fires the same
/// events as a real transaction would.
enum TestModePurchaseDrawer {
  @MainActor
  static func present(
    productIdentifier: String,
    from viewController: UIViewController,
    completion: @escaping (TestModePurchaseResult) -> Void
  ) {
    let alert = UIAlertController(
      title: "🧪 Test Mode Transaction",
      message: "This is a test-mode transaction for:\n\(productIdentifier)\n\nNo real charge will occur.",
      preferredStyle: .actionSheet
    )

    let purchaseAction = UIAlertAction(title: "✅ Purchase", style: .default) { _ in
      completion(.purchased)
    }
    alert.addAction(purchaseAction)

    let abandonAction = UIAlertAction(title: "🚪 Abandon", style: .default) { _ in
      completion(.abandoned)
    }
    alert.addAction(abandonAction)

    let failAction = UIAlertAction(title: "❌ Failure", style: .destructive) { _ in
      completion(.failed)
    }
    alert.addAction(failAction)

    // iPad requires popover source
    if let popover = alert.popoverPresentationController {
      popover.sourceView = viewController.view
      popover.sourceRect = CGRect(
        x: viewController.view.bounds.midX,
        y: viewController.view.bounds.maxY,
        width: 0,
        height: 0
      )
      popover.permittedArrowDirections = .down
    }

    viewController.present(alert, animated: true)
  }
}
