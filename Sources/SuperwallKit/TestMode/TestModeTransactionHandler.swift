//
//  TestModeTransactionHandler.swift
//  Superwall
//
//  Created by Claude on 2026-01-27.
//

#if canImport(WebKit)
#if os(macOS)
import AppKit
#else
import UIKit
#endif

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
    guard let viewController = PlatformViewController.topMostViewController else {
      return .failed(PurchaseError.productUnavailable)
    }

    // Find entitlements for this product from test mode products
    let productEntitlements = testModeManager.products
      .first { $0.identifier == product.productIdentifier }?
      .entitlements ?? []
    let entitlementIds = productEntitlements.map { $0.identifier }

    let showFreeTrial = testModeManager.shouldShowFreeTrial(for: product)

    let result = await withCheckedContinuation { (continuation: CheckedContinuation<TestModePurchaseResult, Never>) in
      TestModePurchaseDrawer.present(
        product: product,
        entitlements: entitlementIds,
        showFreeTrial: showFreeTrial,
        from: viewController
      ) { result in
        continuation.resume(returning: result)
      }
    }

    switch result {
    case .purchased:
      let session = testModeManager.recordPurchase(of: productEntitlements)
      testModeManager.sendOverrides(of: session)

      // Track free trial start if free trial is shown (respecting override)
      if showFreeTrial {
        await Superwall.shared.track(
          InternalSuperwallEvent.FreeTrialStart(
            paywallInfo: .empty(),
            product: product,
            transaction: nil
          )
        )
      }

      return .purchased
    case .abandoned:
      return .cancelled
    case .failed:
      return .failed(PurchaseError.testModeFailure)
    }
  }

  /// Handles a restore in test mode by presenting an entitlement picker drawer.
  ///
  /// Returns `.restored` when the user confirms (with or without entitlements),
  /// or `.failed(nil)` when the user cancels.
  @MainActor
  func handleRestore() async -> RestorationResult {
    guard let viewController = PlatformViewController.topMostViewController else {
      return .failed(nil)
    }

    // Collect unique entitlement IDs across all products
    var seen = Set<String>()
    var uniqueEntitlementIds: [String] = []
    for product in testModeManager.products {
      for entitlement in product.entitlements where seen.insert(entitlement.identifier).inserted {
        uniqueEntitlementIds.append(entitlement.identifier)
      }
    }

    let result = await withCheckedContinuation { (continuation: CheckedContinuation<TestModeRestoreResult, Never>) in
      TestModeRestoreDrawer.present(
        availableEntitlements: uniqueEntitlementIds,
        from: viewController
      ) { result in
        continuation.resume(returning: result)
      }
    }

    switch result {
    case .restored(let entitlements):
      let session = testModeManager.choose(entitlements)
      testModeManager.sendOverrides(of: session)

      // Only count as restored if there are active entitlements
      let hasActive = entitlements.contains { $0.isActive }
      return hasActive ? .restored : .failed(nil)
    case .cancelled:
      return .failed(nil)
    }
  }
}
#endif
