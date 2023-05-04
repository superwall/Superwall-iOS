//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/10/2022.
//

import Foundation
import StoreKit

final class RestorationManager {
  private unowned let storeKitManager: StoreKitManager
  private unowned let sessionEventsManager: SessionEventsManager

  init(
    storeKitManager: StoreKitManager,
    sessionEventsManager: SessionEventsManager
  ) {
    self.storeKitManager = storeKitManager
    self.sessionEventsManager = sessionEventsManager
  }

  @MainActor
  func tryToRestore(_ paywallViewController: PaywallViewController) async {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallTransactions,
      message: "Attempting Restore"
    )

    paywallViewController.loadingState = .loadingPurchase

    let restorationResult: RestorationResult = await storeKitManager.coordinator.txnRestorer.restorePurchases()
    let hasRestored = restorationResult == .restored

    if !Superwall.shared.dependencyContainer.delegateAdapter.hasPurchaseController {
      await storeKitManager.refreshReceipt()
      if hasRestored {
        await storeKitManager.loadPurchasedProducts()
      }
    }

    let isUserSubscribed = Superwall.shared.subscriptionStatus == .active

    if hasRestored && isUserSubscribed {
      Logger.debug(
        logLevel: .debug,
        scope: .paywallTransactions,
        message: "Transactions Restored"
      )
      transactionWasRestored(paywallViewController: paywallViewController)
    } else {
      Logger.debug(
        logLevel: .debug,
        scope: .paywallTransactions,
        message: "Transactions Failed to Restore"
      )

      paywallViewController.presentAlert(
        title: Superwall.shared.options.paywalls.restoreFailed.title,
        message: Superwall.shared.options.paywalls.restoreFailed.message,
        closeActionTitle: Superwall.shared.options.paywalls.restoreFailed.closeButtonTitle
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
      await Superwall.shared.track(trackedEvent)
    }

    if Superwall.shared.options.paywalls.automaticallyDismiss {
      Superwall.shared.dismiss(paywallViewController, result: .restored)
    }
  }
}
