//
//  TestModeTransactionHandler.swift
//  Superwall
//
//  Created by Claude on 2026-01-27.
//

import UIKit

/// Handles purchase and restore flows in test mode.
///
/// Instead of calling StoreKit or the purchase controller, this presents
/// a UI for the user to choose the simulated outcome (purchase/abandon/fail).
final class TestModeTransactionHandler {
  private let testModeManager: TestModeManager

  init(testModeManager: TestModeManager) {
    self.testModeManager = testModeManager
  }

  /// Handles a purchase in test mode by presenting the drawer and returning a `PurchaseResult`.
  @MainActor
  func handlePurchase(
    product: StoreProduct,
    purchaseSource: PurchaseSource
  ) async -> PurchaseResult {
    guard let viewController = topViewController() else {
      return .failed(PurchaseError.productUnavailable)
    }

    let result = await withCheckedContinuation { (continuation: CheckedContinuation<TestModePurchaseResult, Never>) in
      TestModePurchaseDrawer.present(
        productIdentifier: product.productIdentifier,
        from: viewController
      ) { result in
        continuation.resume(returning: result)
      }
    }

    switch result {
    case .purchased:
      // Find entitlement IDs for this product from test mode products
      let entitlementIds = testModeManager.products
        .first { $0.identifier == product.productIdentifier }?
        .entitlements ?? []
      testModeManager.fakePurchase(entitlementIds: entitlementIds)

      // Set subscription status
      let entitlements = testModeManager.testEntitlementIds.map {
        Entitlement(id: $0)
      }
      Superwall.shared.subscriptionStatus = .active(Set(entitlements))

      return .purchased
    case .abandoned:
      return .cancelled
    case .failed:
      return .failed(PurchaseError.productUnavailable)
    }
  }

  /// Handles a restore in test mode by presenting an entitlement picker.
  @MainActor
  func handleRestore() async {
    guard let viewController = topViewController() else { return }

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      let alert = UIAlertController(
        title: "Test Mode Restore",
        message: "Choose the entitlement status to simulate:",
        preferredStyle: .alert
      )

      let activeAction = UIAlertAction(title: "Active Subscription", style: .default) { [weak self] _ in
        // Set all product entitlements as active
        guard let self else {
          continuation.resume()
          return
        }
        let allEntitlementIds = self.testModeManager.products.flatMap { $0.entitlements }
        self.testModeManager.fakePurchase(entitlementIds: allEntitlementIds)
        continuation.resume()
      }
      alert.addAction(activeAction)

      let clearAction = UIAlertAction(title: "No Subscription", style: .default) { [weak self] _ in
        self?.testModeManager.resetEntitlements()
        continuation.resume()
      }
      alert.addAction(clearAction)

      let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
        continuation.resume()
      }
      alert.addAction(cancelAction)

      viewController.present(alert, animated: true)
    }
  }

  @MainActor
  private func topViewController() -> UIViewController? {
    guard let window = UIApplication.sharedApplication?.windows.first(where: { $0.isKeyWindow }),
      var topVC = window.rootViewController else {
      return nil
    }
    while let presented = topVC.presentedViewController {
      topVC = presented
    }
    return topVC
  }
}
