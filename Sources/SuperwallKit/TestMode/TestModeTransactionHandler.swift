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
        let allEntitlements = self.testModeManager.products.flatMap { $0.entitlements }
        self.testModeManager.fakePurchase(entitlements: allEntitlements)

        // Update CustomerInfo and subscription status
        let entitlements = self.testModeManager.testEntitlementIds.map {
          Entitlement(
            id: $0,
            type: .serviceLevel,
            isActive: true,
            store: .appStore,
            state: .subscribed
          )
        }
        let customerInfo = CustomerInfo(
          subscriptions: [],
          nonSubscriptions: [],
          entitlements: entitlements
        )
        self.testModeManager.overriddenCustomerInfo = customerInfo
        Superwall.shared.customerInfo = customerInfo
        let status = SubscriptionStatus.active(Set(entitlements))
        self.testModeManager.overriddenSubscriptionStatus = status
        Superwall.shared.subscriptionStatus = status

        continuation.resume()
      }
      alert.addAction(activeAction)

      let clearAction = UIAlertAction(title: "No Subscription", style: .default) { [weak self] _ in
        self?.testModeManager.resetEntitlements()

        // Clear CustomerInfo and subscription status
        let customerInfo = CustomerInfo(
          subscriptions: [],
          nonSubscriptions: [],
          entitlements: []
        )
        self?.testModeManager.overriddenCustomerInfo = customerInfo
        Superwall.shared.customerInfo = customerInfo
        self?.testModeManager.overriddenSubscriptionStatus = .inactive
        Superwall.shared.subscriptionStatus = .inactive

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
