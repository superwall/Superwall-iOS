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

/// Runs restores one at a time, in the order they were asked for.
///
/// A restore waits on the purchase controller, which may show its own UI, so
/// restores run on a ``SerialTaskCoordinator`` rather than with a lock held.
/// Everything a restore causes goes through its ``RestoreContext``.
final class RestoreFlow {
  let context: RestoreContext
  private let queue = SerialTaskCoordinator()

  /// Set while a restore runs on ``queue``. A restore started from inside it,
  /// such as by the app's purchase controller, runs straight away rather than
  /// waiting behind the one it's part of.
  @TaskLocal private static var isRunningRestore = false

  init(context: RestoreContext) {
    self.context = context
  }

  /// Restores purchases, then tracks, alerts and dismisses as the result calls for.
  @MainActor
  @discardableResult
  func restore(
    _ restoreSource: RestoreSource,
    presentsFailureAlert: Bool = true
  ) async -> RestorationResult {
    // With a purchase controller, the app's restore calls this from inside
    // the paywall's restore, which is already on the queue.
    let isFromPurchaseController = restoreSource == .external
      && context.hasExternalPurchaseController
    if Self.isRunningRestore || isFromPurchaseController {
      return await performRestore(restoreSource, presentsFailureAlert: presentsFailureAlert)
    }
    return await withCheckedContinuation { continuation in
      queue.enqueue { [weak self] in
        guard let self = self else {
          return continuation.resume(returning: .failed(nil))
        }
        let result = await Self.$isRunningRestore.withValue(true) {
          await self.performRestore(restoreSource, presentsFailureAlert: presentsFailureAlert)
        }
        continuation.resume(returning: result)
      }
    }
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
      await context.track(trackedEvent)
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

    let paywallOptions = context.paywallOptions

    func handleRestoreResult(
      _ restorationResult: RestorationResult,
      paywallInfo: PaywallInfo,
      paywallViewController: RestoringPaywall?
    ) async -> RestorationHandlerOutcome {
      let hasRestored = restorationResult == .restored
      let activeEntitlementIds = context.activeEntitlementIds

      #if canImport(WebKit)
      // If web products available, treat restore differently.
      if let restoreUrl = context.restoreAccessURL,
        paywallOptions.shouldShowWebRestorationAlert,
        hasRestored,
        let paywallViewController = paywallViewController {
        // Get entitlement IDs of products from paywall.
        var paywallEntitlementIds: Set<String> = []
        for id in paywallViewController.info.productIds {
          paywallEntitlementIds.formUnion(context.entitlementIds(forProductId: id))
        }

        // If the restored entitlements cover the paywall entitlements,
        // track successful restore.
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
          let hasEntitlements = !activeEntitlementIds.isEmpty
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

          let context = context
          context.presentAlert(
            on: paywallViewController,
            title: title,
            message: message,
            actionTitle: actionTitle,
            closeActionTitle: closeActionTitle,
            // swiftlint:disable:next trailing_closure
            action: {
              context.open(restoreUrl)
            }
          )
          return .webRestore
        }
      }
      #endif

      let hasActiveEntitlements = !activeEntitlementIds.isEmpty

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
          context.notify(paywallViewController, of: .restoreFail(message))
        }
        #endif
        return .failure
      }
    }

    let restoreFailed = paywallOptions.restoreFailed

    #if canImport(WebKit)
    // In test mode, show entitlement picker instead of StoreKit restore
    if let restorationResult = await context.restoreInTestMode() {
      switch restorationResult {
      case .restored:
        await didRestore(restoreSource: restoreSource)
      case .failed:
        if case .internal(let paywallViewController) = restoreSource {
          context.presentAlert(
            on: paywallViewController,
            title: restoreFailed.title,
            message: restoreFailed.message,
            actionTitle: nil,
            closeActionTitle: restoreFailed.closeButtonTitle,
            action: nil
          )
        }
      }
      return restorationResult
    }

    #endif
    switch restoreSource {
    #if canImport(WebKit)
    case .internal(let paywallViewController):
      context.showLoading(on: paywallViewController)

      await logAndTrack(
        state: .start,
        message: "Attempting Restore",
        paywallInfo: paywallViewController.info
      )
      context.notify(paywallViewController, of: .restoreStart)

      let restorationResult = await context.restoreWithPurchaseController()

      let outcome = await handleRestoreResult(
        restorationResult,
        paywallInfo: paywallViewController.info,
        paywallViewController: paywallViewController
      )

      switch outcome {
      case .success:
        context.notify(paywallViewController, of: .restoreComplete)
      case .failure:
        context.presentAlert(
          on: paywallViewController,
          title: restoreFailed.title,
          message: restoreFailed.message,
          actionTitle: nil,
          closeActionTitle: restoreFailed.closeButtonTitle,
          action: nil
        )
      case .webRestore:
        break
      }
      return restorationResult
    #endif
    case .external:
      // If there's an external purchase controller, it means they'll be restoring inside the
      // restore function. So, when that function returns, it will hit the internal case first,
      // then here only to do the actual restore, before returning.
      if context.hasExternalPurchaseController {
        return await context.restoreWithStoreKit()
      }

      await logAndTrack(
        state: .start,
        message: "Attempting Restore",
        paywallInfo: .empty()
      )

      let restorationResult = await context.restoreWithStoreKit()
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
          await context.presentAlert(
            title: restoreFailed.title,
            message: restoreFailed.message,
            closeActionTitle: restoreFailed.closeButtonTitle,
            source: restoreSource
          )
        }
      }

      return restorationResult
    }
  }

  /// Tracks a successful restore, dismissing its paywall if the options say so.
  ///
  /// A restore that comes from a purchase, of a product the user already
  /// owns, is tracked with that purchase's transaction.
  func didRestore(restoreSource: RestoreSource? = nil) async {
    let coordinator = context.purchasingCoordinator
    let purchase = coordinator.purchase

    guard let source = restoreSource ?? purchase?.source.toRestoreSource() else {
      return
    }

    var transaction: StoreTransaction?
    let restoreType: RestoreType
    if let purchase = purchase {
      // There's a purchase, so this was a purchase of a product the user
      // already had.
      transaction = await coordinator.getLatestTransaction(for: purchase)
      restoreType = .viaPurchase(transaction)
    } else {
      // Otherwise it was a generic restore.
      restoreType = .viaRestore
    }

    var isObserved = false
    if case .observeFunc = purchase?.source {
      isObserved = true
    }

    let storeKitVersion: SuperwallOptions.StoreKitVersion =
      context.isUsingStoreKit2 ? .storeKit2 : .storeKit1

    switch source {
    #if canImport(WebKit)
    case .internal(let paywallViewController):
      let paywallInfo = await paywallViewController.info

      let transactionRestore = InternalSuperwallEvent.Transaction(
        state: .restore(restoreType),
        paywallInfo: paywallInfo,
        product: purchase?.product,
        transaction: transaction,
        source: .internal,
        isObserved: isObserved,
        storeKitVersion: storeKitVersion
      )
      await context.track(transactionRestore)
      await context.notify(paywallViewController, of: .transactionRestore)

      if context.paywallOptions.automaticallyDismiss {
        await context.dismiss(paywallViewController, result: .restored)
      }
    #endif
    case .external:
      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .restore(restoreType),
        paywallInfo: .empty(),
        product: purchase?.product,
        transaction: transaction,
        source: .external,
        isObserved: isObserved,
        storeKitVersion: storeKitVersion
      )
      await context.track(trackedEvent)
    }

    // `didRestore` is only reached on a successful restore, at which point
    // receipts/entitlements have just been reloaded. Redeem existing codes so a
    // freshly-restored subscription is linked to the identified user server-side,
    // mirroring the purchase path in `redeemAfterPurchase(for:)`. Skipped in
    // test mode, which sets subscription state without real receipt data
    // (SW-5516: always redeem after a successful purchase & restore).
    if context.isTestMode {
      return
    }
    context.redeemExistingWebEntitlements()
  }
}
