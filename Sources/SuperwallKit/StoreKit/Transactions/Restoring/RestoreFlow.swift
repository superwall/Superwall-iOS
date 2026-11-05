//
//  RestoreFlow.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//
// swiftlint:disable function_body_length type_body_length

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Runs restores, holding where they stand in a ``RestoreStore``.
///
/// A restore waits on the purchase controller, which may show its own UI, so
/// it runs in the caller's task. Only its state changes go through the store.
final class RestoreFlow {
  let store = RestoreStore(initial: RestoreState())

  var isRestoring: Bool {
    store.state.isRestoring
  }

  private let purchaseController: PurchaseController
  private let purchaseManager: PurchaseManager
  private let factory: TransactionManager.Factory
  /// Tracks an event.
  var trackEvent: (Trackable) async -> Void = { event in
    _ = await Superwall.shared.track(event)
  }

  /// Restores through the app's purchase controller, or StoreKit without one.
  /// Replaced in tests, which can't wait on StoreKit.
  var restorePurchases: () async -> RestorationResult

  init(
    purchaseController: PurchaseController,
    purchaseManager: PurchaseManager,
    factory: TransactionManager.Factory
  ) {
    self.purchaseController = purchaseController
    self.purchaseManager = purchaseManager
    self.factory = factory
    restorePurchases = {
      await factory.restorePurchases()
    }
  }

  /// Restores purchases, then tracks, alerts and dismisses as the result calls for.
  @MainActor
  @discardableResult
  func restore(
    _ restoreSource: RestoreSource,
    presentsFailureAlert: Bool = true
  ) async -> RestorationResult {
    store.update(RestoreUpdate.begin(restoreSource))
    let result = await performRestore(
      restoreSource,
      presentsFailureAlert: presentsFailureAlert
    )
    store.update(RestoreUpdate.finish)
    return result
  }

  @MainActor
  private func performRestore(
    _ restoreSource: RestoreSource,
    presentsFailureAlert: Bool
  ) async -> RestorationResult {
    func logAndTrack(
      state: InternalSuperwallEvent.Restore.State,
      message: String,
      paywallInfo: PaywallInfo
    ) async {
      Logger.debug(
        logLevel: .debug,
        scope: .transactions,
        message: message
      )
      let trackedEvent = InternalSuperwallEvent.Restore(
        state: state,
        paywallInfo: paywallInfo
      )
      await trackEvent(trackedEvent)
    }

    enum RestorationHandlerOutcome {
      case success
      case failure
      case webRestore
    }

    #if canImport(WebKit)
    typealias RestoringPaywall = PaywallViewController
    #else
    typealias RestoringPaywall = Never
    #endif

    func handleRestoreResult(
      _ restorationResult: RestorationResult,
      paywallInfo: PaywallInfo,
      paywallViewController: RestoringPaywall?
    ) async -> RestorationHandlerOutcome {
      let hasRestored = restorationResult == .restored

      #if canImport(WebKit)
      // If web products available, treat restore differently.
      if let restoreUrl = factory.makeRestoreAccessURL(),
        Superwall.shared.options.paywalls.shouldShowWebRestorationAlert,
        hasRestored,
        let paywallViewController = paywallViewController {
        // Get entitlement IDs of products from paywall.
        var paywallEntitlementIds: Set<String> = []
        for id in paywallViewController.info.productIds {
          let entitlements = Superwall.shared.entitlements.byProductId(id)
          paywallEntitlementIds.formUnion(entitlements.map { $0.id })
        }

        // If the restored entitlements cover the paywall entitlements,
        // track successful restore.
        let activeEntitlementIds = Set(Superwall.shared.entitlements.active.map { $0.id })
        if paywallEntitlementIds.subtracting(activeEntitlementIds).isEmpty {
          await logAndTrack(
            state: .complete,
            message: "Transactions Restored",
            paywallInfo: paywallInfo
          )
          await didRestore(restoreSource: restoreSource)
          return .success
        } else {
          // Otherwise ask whether they'd like to try restoring from the web.
          let hasEntitlements = !Superwall.shared.entitlements.active.isEmpty
          let bundle = LocalizationLogic.localizedBundle()

          let title = bundle.localizedString(
            forKey: hasEntitlements ? "restore_web_has_subs_title" : "restore_web_no_subs_title",
            value: nil,
            table: nil
          )
          let message = bundle.localizedString(
            forKey: hasEntitlements ? "restore_web_has_subs_message" : "restore_web_no_subs_message",
            value: nil,
            table: nil
          )
          let actionTitle = bundle.localizedString(
            forKey: "restore_web_action_yes",
            value: nil,
            table: nil
          )
          let closeActionTitle = bundle.localizedString(
            forKey: "restore_web_action_cancel",
            value: nil,
            table: nil
          )

          paywallViewController.presentAlert(
            title: title,
            message: message,
            actionTitle: actionTitle,
            closeActionTitle: closeActionTitle,
            // swiftlint:disable:next trailing_closure
            action: {
              guard let sharedApplication = PlatformApplication.sharedApplication else {
                return
              }
              sharedApplication.open(restoreUrl)
            }
          )
          return .webRestore
        }
      }
      #endif

      let hasActiveEntitlements = !Superwall.shared.entitlements.active.isEmpty

      if hasRestored && hasActiveEntitlements {
        await logAndTrack(
          state: .complete,
          message: "Transactions Restored",
          paywallInfo: paywallInfo
        )
        await didRestore(restoreSource: restoreSource)
        return .success
      } else {
        var message = "Transactions Failed to Restore."
        if !hasActiveEntitlements && hasRestored {
          message += " The restoration result is \"restored\" but there are no active "
            + "entitlements. Ensure the active entitlements are set before confirming "
            + "successful restoration."
        }
        if case .failed(let error) = restorationResult,
          let error = error {
          message += " Original restoration error message: \(error.safeLocalizedDescription)"
        }
        await logAndTrack(
          state: .fail(message),
          message: message,
          paywallInfo: paywallInfo
        )
        #if canImport(WebKit)
        if let paywallViewController = paywallViewController {
          paywallViewController.webView.messageHandler.handle(.restoreFail(message))
        }
        #endif
        return .failure
      }
    }

    #if canImport(WebKit)
    // In test mode, show entitlement picker instead of StoreKit restore
    let testModeManager = factory.makeTestModeManager()
    if testModeManager.isTestMode {
      let handler = TestModeTransactionHandler(testModeManager: testModeManager)
      let restorationResult = await handler.handleRestore()

      switch restorationResult {
      case .restored:
        await didRestore(restoreSource: restoreSource)
      case .failed:
        #if canImport(WebKit)
        if case .internal(let paywallViewController) = restoreSource {
          paywallViewController.presentAlert(
            title: Superwall.shared.options.paywalls.restoreFailed.title,
            message: Superwall.shared.options.paywalls.restoreFailed.message,
            closeActionTitle: Superwall.shared.options.paywalls.restoreFailed.closeButtonTitle
          )
        }
        #endif
      }
      return restorationResult
    }

    #endif
    switch restoreSource {
    #if canImport(WebKit)
    case .internal(let paywallViewController):
      paywallViewController.loadingState = .loadingPurchase

      await logAndTrack(
        state: .start,
        message: "Attempting Restore",
        paywallInfo: paywallViewController.info
      )
      paywallViewController.webView.messageHandler.handle(.restoreStart)

      let restorationResult = await purchaseController.restorePurchases()

      let outcome = await handleRestoreResult(
        restorationResult,
        paywallInfo: paywallViewController.info,
        paywallViewController: paywallViewController
      )

      switch outcome {
      case .success:
        paywallViewController.webView.messageHandler.handle(.restoreComplete)
      case .failure:
        paywallViewController.presentAlert(
          title: Superwall.shared.options.paywalls.restoreFailed.title,
          message: Superwall.shared.options.paywalls.restoreFailed.message,
          closeActionTitle: Superwall.shared.options.paywalls.restoreFailed.closeButtonTitle
        )
      case .webRestore:
        break
      }
      return restorationResult
    #endif
    case .external:
      let hasExternalPurchaseController = factory.makeHasExternalPurchaseController()

      // If there's an external purchase controller, it means they'll be restoring inside the
      // restore function. So, when that function returns, it will hit the internal case first,
      // then here only to do the actual restore, before returning.
      if hasExternalPurchaseController {
        return await restorePurchases()
      }

      await logAndTrack(
        state: .start,
        message: "Attempting Restore",
        paywallInfo: .empty()
      )

      let restorationResult = await restorePurchases()
      let outcome = await handleRestoreResult(
        restorationResult,
        paywallInfo: .empty(),
        paywallViewController: nil
      )

      switch outcome {
      case .success,
        .webRestore:
        break
      case .failure:
        if presentsFailureAlert {
          await TransactionAlert.present(
            title: Superwall.shared.options.paywalls.restoreFailed.title,
            message: Superwall.shared.options.paywalls.restoreFailed.message,
            closeActionTitle: Superwall.shared.options.paywalls.restoreFailed.closeButtonTitle,
            source: restoreSource
          )
        }
      }

      return restorationResult
    }
  }

  func didRestore(restoreSource: RestoreSource? = nil) async {
    let coordinator = factory.makePurchasingCoordinator()
    var transaction: StoreTransaction?
    let restoreType: RestoreType

    let coordinatorSource = coordinator.source
    guard let source = restoreSource ?? coordinatorSource?.toRestoreSource() else {
      return
    }

    let product = coordinator.product

    if let product = product {
      // Product exists so much have been via a purchase of a specific product.
      transaction = await coordinator.getLatestTransaction(
        forProductId: product.productIdentifier,
        factory: factory
      )
      restoreType = .viaPurchase(transaction)
    } else {
      // Otherwise it was a generic restore.
      restoreType = .viaRestore
    }

    var isObserved = false
    if case .observeFunc = coordinatorSource {
      isObserved = true
    }

    switch source {
    #if canImport(WebKit)
    case .internal(let paywallViewController):
      let paywallInfo = await paywallViewController.info

      let transactionRestore = InternalSuperwallEvent.Transaction(
        state: .restore(restoreType),
        paywallInfo: paywallInfo,
        product: product,
        transaction: transaction,
        source: .internal,
        isObserved: isObserved,
        storeKitVersion: purchaseManager.isUsingSK2 ? .storeKit2 : .storeKit1
      )
      await trackEvent(transactionRestore)
      await paywallViewController.webView.messageHandler.handle(.transactionRestore)

      let superwallOptions = factory.makeSuperwallOptions()
      if superwallOptions.paywalls.automaticallyDismiss {
        await Superwall.shared.dismiss(paywallViewController, result: .restored)
      }
    #endif
    case .external:
      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .restore(restoreType),
        paywallInfo: .empty(),
        product: product,
        transaction: transaction,
        source: .external,
        isObserved: isObserved,
        storeKitVersion: purchaseManager.isUsingSK2 ? .storeKit2 : .storeKit1
      )
      await trackEvent(trackedEvent)
    }

    // `didRestore` is only reached on a successful restore, at which point
    // receipts/entitlements have just been reloaded. Redeem existing codes so a
    // freshly-restored subscription is linked to the identified user server-side,
    // mirroring the purchase path in `redeemAfterPurchase(for:)`. Skipped in
    // test mode, which sets subscription state without real receipt data
    // (SW-5516: always redeem after a successful purchase & restore).
    if factory.makeTestModeManager().isTestMode {
      return
    }
    Task {
      await Superwall.shared.dependencyContainer.webEntitlementRedeemer.redeem(.existingCodes)
    }
  }
}
