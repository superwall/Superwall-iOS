//
//  RestoreContext.swift
//  SuperwallKit
//
//  Created by Superwall on 06/11/2026.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Everything a restore reads from and causes in the rest of the SDK.
/// ``AppRestoreContext`` provides the real one, and tests a fake that records
/// the calls.
protocol RestoreContext: AnyObject {
  var purchasingCoordinator: PurchasingCoordinator { get }
  var hasExternalPurchaseController: Bool { get }
  var isUsingStoreKit2: Bool { get }
  var isTestMode: Bool { get }
  var paywallOptions: PaywallOptions { get }
  /// Where the user can restore web purchases, if the app sells any.
  var restoreAccessURL: URL? { get }
  var activeEntitlementIds: Set<String> { get }
  func entitlementIds(forProductId productId: String) -> Set<String>

  func track(_ event: Trackable) async
  /// Restores through the purchase controller, which may be the app's.
  func restoreWithPurchaseController() async -> RestorationResult
  /// Restores through the SDK's own StoreKit purchaser.
  func restoreWithStoreKit() async -> RestorationResult
  /// Lets the tester pick what a restore restores, or returns `nil` when
  /// not in test mode.
  func restoreInTestMode() async -> RestorationResult?
  /// Shows an alert on the top-most view controller.
  func presentAlert(
    title: String,
    message: String,
    closeActionTitle: String,
    source: RestoreSource
  ) async
  func redeemExistingWebEntitlements()

  #if canImport(WebKit)
  @MainActor
  func showLoading(on paywall: PaywallViewController)
  @MainActor
  func notify(_ paywall: PaywallViewController, of message: PaywallMessage)
  @MainActor
  // swiftlint:disable:next function_parameter_count
  func presentAlert(
    on paywall: PaywallViewController,
    title: String,
    message: String,
    actionTitle: String?,
    closeActionTitle: String,
    action: (() -> Void)?
  )
  @MainActor
  func open(_ url: URL)
  func dismiss(_ paywall: PaywallViewController, result: PaywallResult) async
  #endif
}

/// The real restore side effects.
final class AppRestoreContext: RestoreContext {
  private let purchaseController: PurchaseController
  private let purchaseManager: PurchaseManager
  private let factory: TransactionManager.Factory

  /// Tracks an event. ``TransactionManager`` points this at its own
  /// `trackEvent`, so replacing that in a test covers restores too.
  var trackEvent: (Trackable) async -> Void = { event in
    _ = await Superwall.shared.track(event)
  }

  init(
    purchaseController: PurchaseController,
    purchaseManager: PurchaseManager,
    factory: TransactionManager.Factory
  ) {
    self.purchaseController = purchaseController
    self.purchaseManager = purchaseManager
    self.factory = factory
  }

  var purchasingCoordinator: PurchasingCoordinator {
    factory.makePurchasingCoordinator()
  }

  var hasExternalPurchaseController: Bool {
    factory.makeHasExternalPurchaseController()
  }

  var isUsingStoreKit2: Bool {
    purchaseManager.isUsingSK2
  }

  var isTestMode: Bool {
    factory.makeTestModeManager().isTestMode
  }

  var paywallOptions: PaywallOptions {
    factory.makeSuperwallOptions().paywalls
  }

  var restoreAccessURL: URL? {
    factory.makeRestoreAccessURL()
  }

  var activeEntitlementIds: Set<String> {
    Set(Superwall.shared.entitlements.active.map { $0.id })
  }

  func entitlementIds(forProductId productId: String) -> Set<String> {
    Set(Superwall.shared.entitlements.byProductId(productId).map { $0.id })
  }

  func track(_ event: Trackable) async {
    await trackEvent(event)
  }

  func restoreWithPurchaseController() async -> RestorationResult {
    return await purchaseController.restorePurchases()
  }

  func restoreWithStoreKit() async -> RestorationResult {
    return await factory.restorePurchases()
  }

  func restoreInTestMode() async -> RestorationResult? {
    #if canImport(WebKit)
    let testModeManager = factory.makeTestModeManager()
    guard testModeManager.isTestMode else {
      return nil
    }
    let handler = TestModeTransactionHandler(testModeManager: testModeManager)
    return await handler.handleRestore()
    #else
    return nil
    #endif
  }

  func presentAlert(
    title: String,
    message: String,
    closeActionTitle: String,
    source: RestoreSource
  ) async {
    await TransactionAlert.present(
      title: title,
      message: message,
      closeActionTitle: closeActionTitle,
      source: source
    )
  }

  func redeemExistingWebEntitlements() {
    Task {
      await Superwall.shared.dependencyContainer.webEntitlementRedeemer.redeem(.existingCodes)
    }
  }

  #if canImport(WebKit)
  @MainActor
  func showLoading(on paywall: PaywallViewController) {
    paywall.loadingState = .loadingPurchase
  }

  @MainActor
  func notify(_ paywall: PaywallViewController, of message: PaywallMessage) {
    paywall.webView.messageHandler.handle(message)
  }

  @MainActor
  // swiftlint:disable:next function_parameter_count
  func presentAlert(
    on paywall: PaywallViewController,
    title: String,
    message: String,
    actionTitle: String?,
    closeActionTitle: String,
    action: (() -> Void)?
  ) {
    paywall.presentAlert(
      title: title,
      message: message,
      actionTitle: actionTitle,
      closeActionTitle: closeActionTitle,
      action: action
    )
  }

  @MainActor
  func open(_ url: URL) {
    PlatformApplication.sharedApplication?.open(url)
  }

  func dismiss(_ paywall: PaywallViewController, result: PaywallResult) async {
    await Superwall.shared.dismiss(paywall, result: result)
  }
  #endif
}
