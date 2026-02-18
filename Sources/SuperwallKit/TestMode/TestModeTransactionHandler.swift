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
  // swiftlint:disable:next function_body_length
  func handlePurchase(
    product: StoreProduct,
    purchaseSource: PurchaseSource
  ) async -> PurchaseResult {
    guard let viewController = topViewController() else {
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
      testModeManager.fakePurchase(entitlements: productEntitlements)

      // Create entitlements with proper state (subscribed since it's a purchase)
      let entitlements = testModeManager.testEntitlementIds.map {
        Entitlement(
          id: $0,
          type: .serviceLevel,
          isActive: true,
          store: .appStore,
          state: .subscribed
        )
      }

      // Update CustomerInfo with the new entitlements
      let updatedCustomerInfo = CustomerInfo(
        subscriptions: [],
        nonSubscriptions: [],
        entitlements: entitlements
      )
      testModeManager.overriddenCustomerInfo = updatedCustomerInfo
      Superwall.shared.customerInfo = updatedCustomerInfo

      // Set subscription status based on whether any entitlements are active
      let entitlementSet = Set(entitlements)
      let hasActiveEntitlements = entitlements.contains { $0.isActive }
      if hasActiveEntitlements {
        let status = SubscriptionStatus.active(entitlementSet)
        testModeManager.overriddenSubscriptionStatus = status
        Superwall.shared.subscriptionStatus = status
      } else {
        testModeManager.overriddenSubscriptionStatus = .inactive
        Superwall.shared.subscriptionStatus = .inactive
      }

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
    guard let viewController = topViewController() else {
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
      let hasActive = entitlements.contains { $0.isActive }

      if entitlements.isEmpty {
        // No Subscription — clear everything
        testModeManager.resetEntitlements()

        let customerInfo = CustomerInfo(
          subscriptions: [],
          nonSubscriptions: [],
          entitlements: []
        )
        testModeManager.overriddenCustomerInfo = customerInfo
        Superwall.shared.customerInfo = customerInfo
        testModeManager.overriddenSubscriptionStatus = .inactive
        Superwall.shared.subscriptionStatus = .inactive
      } else {
        // Update test mode manager with selected entitlement IDs
        let activeIds = Set(entitlements.map { $0.id })
        testModeManager.setEntitlements(activeIds)

        let customerInfo = CustomerInfo(
          subscriptions: [],
          nonSubscriptions: [],
          entitlements: Array(entitlements)
        )
        testModeManager.overriddenCustomerInfo = customerInfo
        Superwall.shared.customerInfo = customerInfo

        if hasActive {
          let status = SubscriptionStatus.active(entitlements)
          testModeManager.overriddenSubscriptionStatus = status
          Superwall.shared.subscriptionStatus = status
        } else {
          testModeManager.overriddenSubscriptionStatus = .inactive
          Superwall.shared.subscriptionStatus = .inactive
        }
      }

      // Only count as restored if there are active entitlements
      return hasActive ? .restored : .failed(nil)
    case .cancelled:
      return .failed(nil)
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
