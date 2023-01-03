//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/10/2022.
//

import Foundation
import StoreKit

final class RestorationHandler {
  private unowned let storeKitManager: StoreKitManager
  private unowned let sessionEventsManager: SessionEventsManager
  private let superwall: Superwall.Type

  init(
    storeKitManager: StoreKitManager,
    sessionEventsManager: SessionEventsManager,
    superwall: Superwall.Type = Superwall.self
  ) {
    self.storeKitManager = storeKitManager
    self.sessionEventsManager = sessionEventsManager
    self.superwall = superwall
  }

  @MainActor
  func tryToRestore(_ paywallViewController: PaywallViewController) async {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Attempting Restore"
    )

    paywallViewController.loadingState = .loadingPurchase

    let hasRestored = await storeKitManager.coordinator.txnRestorer.restorePurchases()
    var isUserSubscribed = false

    if hasRestored {
      await storeKitManager.loadPurchasedProducts()
      isUserSubscribed = storeKitManager.coordinator.subscriptionStatusHandler.isSubscribed()
    }

    paywallViewController.loadingState = .ready

    // TODO: Look over the tracking of the restore here
    if hasRestored,
      isUserSubscribed {
      Logger.debug(
        logLevel: .debug,
        scope: .paywallTransactions,
        message: "Transaction Restored"
      )
      transactionWasRestored(paywallViewController: paywallViewController)
    } else {
      Logger.debug(
        logLevel: .debug,
        scope: .paywallTransactions,
        message: "Transaction Failed to Restore"
      )

      paywallViewController.presentAlert(
        title: superwall.options.paywalls.restoreFailed.title,
        message: superwall.options.paywalls.restoreFailed.message,
        closeActionTitle: superwall.options.paywalls.restoreFailed.closeButtonTitle
      )
    }
  }

  @MainActor
  private func transactionWasRestored(paywallViewController: PaywallViewController) {
    let paywallInfo = paywallViewController.paywallInfo
    Task.detached(priority: .utility) {
      let trackedEvent = InternalSuperwallEvent.Transaction(
        state: .restore,
        paywallInfo: paywallInfo,
        product: nil,
        model: nil
      )
      await self.superwall.track(trackedEvent)

      // If on iOS 15+ we don't use the Sk1 transaction observer.
      // So will need to track transactions here.
      if #available(iOS 15.0, *) {
        // TODO: Why are we doing this when we did stuff earlier in restore didn't we or at least in the sk1 one?
        await self.sessionEventsManager.triggerSession.trackTransactionRestoration()
      }
    }

    if Superwall.options.paywalls.automaticallyDismiss {
      superwall.shared.dismiss(paywallViewController, state: .restored)
    } else {
      paywallViewController.loadingState = .ready
    }
  }
}
