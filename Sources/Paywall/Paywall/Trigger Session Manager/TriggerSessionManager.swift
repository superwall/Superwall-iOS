//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/04/2022.
//

import UIKit
import StoreKit

final class TriggerSessionManager {
  // TODO: Store last 20 triggersessions on disk.
  // TODO: On holdout, send a completed triggersession back.
  // TODO: If no rules matched then send completed triggersession back

  static let shared = TriggerSessionManager()
  private let queue = SessionEventsQueue()
  private var triggerSession: TriggerSession?
  private var transactionCount: TriggerSession.Transaction.Count?
  enum LoadState {
    case start
    case end
    case fail
  }

  private init() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }

  private func enqueueTriggerSession() {
    guard let triggerSession = triggerSession else {
      return
    }
    queue.enqueue(triggerSession)
  }

  // MARK: - App Lifecycle

  /* Context for how to end a paywall session
   *     1. on app close, add paywall_session to QUEUE and treat app close as paywall session end
   *     2. on paywall close, regardless of what paywall_session_end_at is currently set at, update it to the paywall close time
   *     3. TODO: be sure to test what happens during a transaction, as app leaves foreground in that scenario
   *     4. new paywall_session id gets created every paywall_open
   */

  @objc private func applicationDidEnterBackground() {
    triggerSession?.endAt = Date()
    enqueueTriggerSession()
  }
  // TODO: Trigger session updates need to fire once after all relevant updates completed
  @objc private func applicationWillEnterForeground() {
    triggerSession?.id = UUID().uuidString
    triggerSession?.endAt = nil
    enqueueTriggerSession()
  }

  // MARK: - Session Lifecycle

  func createSession(
    from presentationInfo: PresentationInfo,
    on presentingViewController: UIViewController?,
    paywallResponse: PaywallResponse? = nil,
    immediatelyEndSession: Bool = false
  ) {
    guard let outcome = TriggerSessionManagerLogic.outcome(
      presentationInfo: presentationInfo,
      presentingViewController: presentingViewController,
      paywallResponse: paywallResponse
    ) else {
      return
    }
    
    let session = TriggerSession(
      configRequestId: Storage.shared.configRequestId,
      userAttributes: JSON(Storage.shared.userAttributes),
      presentationOutcome: outcome.presentationOutcome,
      trigger: outcome.trigger,
      paywall: outcome.paywall,
      products: TriggerSession.Products(
        allProducts: StoreKitManager.shared.swProducts,
        loadingInfo: .init(
          startAt: paywallResponse?.productsLoadStartTime,
          endAt: paywallResponse?.productsLoadCompleteTime,
          failAt: paywallResponse?.productsLoadFailTime
        )
      ),
      appSession: AppSessionManager.shared.appSession
    )

    self.triggerSession = session

    if immediatelyEndSession {
      endSession()
    } else {
      enqueueTriggerSession()
    }
  }

  /// Ends the session and resets it to nil
  func endSession() {
    triggerSession?.endAt = Date()
    enqueueTriggerSession()

    transactionCount = nil
    triggerSession = nil
  }
  

  // MARK: - App Session

  /// Adds the latest app session to the trigger
  func updateAppSession() {
    triggerSession?.appSession = AppSessionManager.shared.appSession
    enqueueTriggerSession()
  }

  // MARK: - Paywall

  /// Tracks when the paywall was opened
  func trackPaywallOpen() {
    triggerSession?.paywall?.action.openAt = Date()
    enqueueTriggerSession()
  }

  /// Tracks when paywall was closed and then ends the session.
  func trackPaywallClose() {
    triggerSession?.paywall?.action.closeAt = Date()
    endSession()
  }

  // MARK: - WebView Load
  /// Tracks when a webview started to load
  func trackWebViewLoad(state: LoadState) {
    switch state {
    case .start:
      triggerSession?
        .paywall?
        .webViewLoading
        .startAt = Date()
    case .end:
      triggerSession?
        .paywall?
        .webViewLoading
        .endAt = Date()
    case .fail:
      triggerSession?
        .paywall?
        .webViewLoading
        .failAt = Date()
    }

    enqueueTriggerSession()
  }

  // MARK: - Paywall Response Load

  func trackPaywallResponseLoad(state: LoadState) {
    switch state {
    case .start:
      triggerSession?
        .paywall?
        .responseLoading
        .startAt = Date()
    case .end:
      triggerSession?
        .paywall?
        .responseLoading
        .endAt = Date()
    case .fail:
      triggerSession?
        .paywall?
        .responseLoading
        .failAt = Date()
    }

    enqueueTriggerSession()
  }

  // MARK: - Products

  func trackProductsLoad(state: LoadState) {
    switch state {
    case .start:
      triggerSession?
        .products
        .loadingInfo
        .startAt = Date()
    case .end:
      triggerSession?
        .products
        .loadingInfo
        .endAt = Date()
    case .fail:
      triggerSession?
        .products
        .loadingInfo
        .failAt = Date()
    }

    enqueueTriggerSession()
  }

  func storeAllProducts(_ products: [SWProduct]) {
    triggerSession?
      .products
      .allProducts = products
    enqueueTriggerSession()
  }

  // MARK: - Transactions

  func trackBeginTransaction(of product: SKProduct) {
    // Need a local transaction count, per trigger session.
    if transactionCount != nil {
      transactionCount?.start += 1
    } else {
      transactionCount = .init(start: 1)
    }

    let productIndex = StoreKitManager.shared.swProducts.firstIndex {
      $0.productIdentifier == product.productIdentifier
    } ?? 0
    triggerSession?.transaction = .init(
      startAt: Date(),
      count: transactionCount,
      product: .init(from: product, index: productIndex)
    )
    enqueueTriggerSession()
  }

  /// When a transaction error occurred.
  func trackTransactionError() {
    transactionCount?.fail += 1

    triggerSession?
      .transaction?
      .count = transactionCount

    triggerSession?
      .transaction?
      .endAt = Date()

    triggerSession?
      .transaction?
      .status = .fail

    enqueueTriggerSession()
  }

  /// When a transaction has been abandoned.
  func trackTransactionAbandon() {
    transactionCount?.abandon += 1

    triggerSession?
      .transaction?
      .count = transactionCount

    triggerSession?
      .transaction?
      .status = .abandon

    triggerSession?
      .transaction?
      .endAt = Date()

    enqueueTriggerSession()
  }

  /// When a transaction is restored. A restore could have been triggered without any other transaction occurring.
  func trackTransactionRestoration(
    withId id: String?,
    product: SKProduct,
    isFreeTrialAvailable: Bool
  ) {
    if transactionCount != nil {
      transactionCount?.restore += 1
    } else {
      transactionCount = .init(restore: 1)
    }

    var transaction: TriggerSession.Transaction
    if var existingTransaction = triggerSession?.transaction {
      existingTransaction.status = .complete
      existingTransaction.endAt = Date()
      transaction = existingTransaction
    } else {
      let transactionOutcome = TriggerSessionManagerLogic.getTransactionOutcome(
        for: product,
        isFreeTrialAvailable: isFreeTrialAvailable
      )
      let productIndex = StoreKitManager.shared.swProducts.firstIndex {
        $0.productIdentifier == product.productIdentifier
      } ?? 0
      transaction = .init(
        id: id,
        startAt: Date(),
        endAt: Date(),
        outcome: transactionOutcome,
        count: transactionCount,
        status: .complete,
        product: .init(from: product, index: productIndex)
      )
    }
    triggerSession?
      .transaction = transaction

    enqueueTriggerSession()
  }

  func trackDeferredTransaction() {
    transactionCount?.fail += 1

    triggerSession?
      .transaction?
      .count = transactionCount

    triggerSession?
      .transaction?
      .status = .fail

    triggerSession?.transaction?.endAt = Date()
    enqueueTriggerSession()
  }

  func trackTransactionSucceeded(
    withId id: String?,
    for product: SKProduct,
    isFreeTrialAvailable: Bool
  ) {
    transactionCount?.complete += 1

    triggerSession?
      .transaction?
      .count = transactionCount

    triggerSession?
      .transaction?
      .id = id

    triggerSession?
      .transaction?
      .endAt = Date()

    triggerSession?
      .transaction?
      .status = .complete

    triggerSession?
      .paywall?
      .action
      .convertedAt = Date()

    if product.subscriptionPeriod == nil {
      triggerSession?
        .transaction?
        .outcome = .nonRecurringProductPurchase
    }

    if isFreeTrialAvailable {
      triggerSession?
        .transaction?
        .outcome = .trialStart
    } else {
      triggerSession?
        .transaction?
        .outcome = .subscriptionStart
    }
    enqueueTriggerSession()
  }
}
