//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/04/2022.
//

import UIKit
import StoreKit

final class TriggerSessionManager {
  /// The shared instance of the class
  static let shared = TriggerSessionManager()

  /// A queue of trigger session events that get sent to the server.
  private let queue = SessionEventsQueue()

  /// The list of all potential trigger sessions, keyed by the trigger event name, created after receiving the config.
  private var pendingTriggerSessions: [String: TriggerSession] = [:]

  /// The active trigger session.
  private var activeTriggerSession: TriggerSession?

  /// A local count for transactions used within the trigger session.
  private var transactionCount: TriggerSession.Transaction.Count?

  enum LoadState {
    case start
    case end
    case fail
  }

  private init() {
    postCachedTriggerSessions()
    addObservers()
  }

  /// Gets the last 20 cached trigger sessions from the last time the app was terminated,
  /// sends them back to the server, then clears cache.
  private func postCachedTriggerSessions() {
    let cachedTriggerSessions = Storage.shared.getCachedTriggerSessions()
    if cachedTriggerSessions.isEmpty {
      return
    }
    let sessionEvents = SessionEventsRequest(
      triggerSessions: cachedTriggerSessions
    )
    Network.shared.sendSessionEvents(sessionEvents)
    Storage.shared.clearCachedTriggerSessions()
  }

  private func addObservers() {
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

  // MARK: - App Lifecycle

  /* Context for how to end a paywall session
   *     1. on app close, add paywall_session to QUEUE and treat app close as paywall session end
   *     2. on paywall close, regardless of what paywall_session_end_at is currently set at, update it to the paywall close time
   *     3. TODO: be sure to test what happens during a transaction, as app leaves foreground in that scenario
   */

  @objc private func applicationDidEnterBackground() {
    activeTriggerSession?.endAt = Date()
    enqueueCurrentTriggerSession()
  }
  // TODO: Trigger session updates need to fire once after all relevant updates completed
  @objc private func applicationWillEnterForeground() {
    activeTriggerSession?.id = UUID().uuidString
    activeTriggerSession?.endAt = nil
    enqueueCurrentTriggerSession()
  }

  // MARK: - Session Lifecycle

  /// Creates a session for each potential trigger on config and manual paywall presentation and sends them off to the server.
  func createSessions(from config: Config) {
    // Loop through triggers and create a session for each.
    for trigger in config.triggers {
      let pendingTriggerSession = TriggerSessionManagerLogic.createPendingTriggerSession(
        configRequestId: Storage.shared.configRequestId,
        userAttributes: Storage.shared.userAttributes,
        isSubscribed: Paywall.delegate?.isUserSubscribed() ?? false,
        eventName: trigger.eventName,
        products: StoreKitManager.shared.swProducts,
        appSession: AppSessionManager.shared.appSession
      )
      pendingTriggerSessions[trigger.eventName] = pendingTriggerSession
    }

    // Add in the default paywall session.
    let defaultEventName = SuperwallEvent.ManualPresent().rawName
    let defaultPaywallSession = TriggerSessionManagerLogic.createPendingTriggerSession(
      configRequestId: Storage.shared.configRequestId,
      userAttributes: Storage.shared.userAttributes,
      isSubscribed: Paywall.delegate?.isUserSubscribed() ?? false,
      eventName: defaultEventName,
      products: StoreKitManager.shared.swProducts,
      appSession: AppSessionManager.shared.appSession
    )
    pendingTriggerSessions[defaultEventName] = defaultPaywallSession

    // Send the sessions back to the server.
    enqueuePendingTriggerSessions()
  }

  func activateSession(
    for presentationInfo: PresentationInfo,
    on presentingViewController: UIViewController?,
    paywallResponse: PaywallResponse? = nil,
    immediatelyEndSession: Bool = false
  ) {
    guard let eventName = presentationInfo.eventName else {
      // The paywall is being presented by identifier and that's not supported.
      return
    }
    guard var session = pendingTriggerSessions[eventName] else {
      return
    }
    guard let outcome = TriggerSessionManagerLogic.outcome(
      presentationInfo: presentationInfo,
      presentingViewController: presentingViewController,
      paywallResponse: paywallResponse
    ) else {
      return
    }

    // Update trigger session
    session.userAttributes = JSON(Storage.shared.userAttributes)
    session.presentationOutcome = outcome.presentationOutcome
    session.trigger = outcome.trigger
    session.paywall = outcome.paywall
    session.products = TriggerSession.Products(
      allProducts: StoreKitManager.shared.swProducts,
      loadingInfo: .init(
        startAt: paywallResponse?.productsLoadStartTime,
        endAt: paywallResponse?.productsLoadCompleteTime,
        failAt: paywallResponse?.productsLoadFailTime
      )
    )
    session.appSession = AppSessionManager.shared.appSession

    self.activeTriggerSession = session
    pendingTriggerSessions[eventName] = nil

    if immediatelyEndSession {
      endSession()
    } else {
      enqueueCurrentTriggerSession()
    }
  }

  /// Ends the session and resets it to nil
  func endSession() {
    guard var currentTriggerSession = activeTriggerSession else {
      return
    }
    // Send off current trigger session
    currentTriggerSession.endAt = Date()
    activeTriggerSession = currentTriggerSession
    enqueueCurrentTriggerSession()

    // Recreate a pending trigger session
    let eventName = currentTriggerSession.trigger.eventName
    let pendingTriggerSession = TriggerSessionManagerLogic.createPendingTriggerSession(
      configRequestId: Storage.shared.configRequestId,
      userAttributes: Storage.shared.userAttributes,
      isSubscribed: Paywall.delegate?.isUserSubscribed() ?? false,
      eventName: eventName,
      products: StoreKitManager.shared.swProducts,
      appSession: AppSessionManager.shared.appSession
    )
    pendingTriggerSessions[eventName] = pendingTriggerSession

    // Reset state of current trigger session
    transactionCount = nil
    self.activeTriggerSession = nil
  }

  /// Queues the trigger session to be sent back to the server.
  private func enqueueCurrentTriggerSession() {
    guard var triggerSession = activeTriggerSession else {
      return
    }
    triggerSession.isSubscribed = Paywall.delegate?.isUserSubscribed() ?? false
    queue.enqueue(triggerSession)
  }

  /// Queues all the pending trigger sessions to be sent back to the server.
  private func enqueuePendingTriggerSessions() {
    var triggerSessionArray: [TriggerSession] = []

    for eventName in pendingTriggerSessions.keys {
      guard var pendingTriggerSession = pendingTriggerSessions[eventName] else {
        continue
      }
      pendingTriggerSession.isSubscribed = Paywall.delegate?.isUserSubscribed() ?? false

      triggerSessionArray.append(pendingTriggerSession)
      pendingTriggerSessions[eventName] = pendingTriggerSession
    }

    let triggerSessionsArray = Array(pendingTriggerSessions.values)
    queue.enqueue(triggerSessionsArray)
  }
  
  // MARK: - App Session

  /// Adds the latest app session to the trigger
  func updateAppSession() {
    activeTriggerSession?.appSession = AppSessionManager.shared.appSession

    for eventName in pendingTriggerSessions.keys {
      var pendingTriggerSession = pendingTriggerSessions[eventName]
      pendingTriggerSession?.appSession = AppSessionManager.shared.appSession
      pendingTriggerSessions[eventName] = pendingTriggerSession
    }

    enqueueCurrentTriggerSession()
  }

  // MARK: - Paywall

  /// Tracks when the paywall was opened
  func trackPaywallOpen() {
    activeTriggerSession?.paywall?.action.openAt = Date()
    enqueueCurrentTriggerSession()
  }

  /// Tracks when paywall was closed and then ends the session.
  func trackPaywallClose() {
    activeTriggerSession?.paywall?.action.closeAt = Date()
    endSession()
  }

  // MARK: - WebView Load

  /// Tracks when a webview started to load
  func trackWebViewLoad(state: LoadState) {
    switch state {
    case .start:
      activeTriggerSession?
        .paywall?
        .webViewLoading
        .startAt = Date()
    case .end:
      activeTriggerSession?
        .paywall?
        .webViewLoading
        .endAt = Date()
    case .fail:
      activeTriggerSession?
        .paywall?
        .webViewLoading
        .failAt = Date()
    }

    enqueueCurrentTriggerSession()
  }

  // MARK: - Paywall Response Load

  func trackPaywallResponseLoad(state: LoadState) {
    switch state {
    case .start:
      activeTriggerSession?
        .paywall?
        .responseLoading
        .startAt = Date()
    case .end:
      activeTriggerSession?
        .paywall?
        .responseLoading
        .endAt = Date()
    case .fail:
      activeTriggerSession?
        .paywall?
        .responseLoading
        .failAt = Date()
    }

    enqueueCurrentTriggerSession()
  }

  // MARK: - Products

  func trackProductsLoad(state: LoadState) {
    switch state {
    case .start:
      activeTriggerSession?
        .products
        .loadingInfo?
        .startAt = Date()
    case .end:
      activeTriggerSession?
        .products
        .loadingInfo?
        .endAt = Date()
    case .fail:
      activeTriggerSession?
        .products
        .loadingInfo?
        .failAt = Date()
    }

    enqueueCurrentTriggerSession()
  }

  func storeAllProducts(_ products: [SWProduct]) {
    activeTriggerSession?
      .products
      .allProducts = products
    enqueueCurrentTriggerSession()
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
    activeTriggerSession?.transaction = .init(
      startAt: Date(),
      count: transactionCount,
      product: .init(from: product, index: productIndex)
    )
    enqueueCurrentTriggerSession()
  }

  /// When a transaction error occurred.
  func trackTransactionError() {
    transactionCount?.fail += 1

    activeTriggerSession?
      .transaction?
      .count = transactionCount

    activeTriggerSession?
      .transaction?
      .endAt = Date()

    activeTriggerSession?
      .transaction?
      .status = .fail

    enqueueCurrentTriggerSession()
  }

  /// When a transaction has been abandoned.
  func trackTransactionAbandon() {
    transactionCount?.abandon += 1

    activeTriggerSession?
      .transaction?
      .count = transactionCount

    activeTriggerSession?
      .transaction?
      .status = .abandon

    activeTriggerSession?
      .transaction?
      .endAt = Date()

    enqueueCurrentTriggerSession()
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
    if var existingTransaction = activeTriggerSession?.transaction {
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
    activeTriggerSession?
      .transaction = transaction

    enqueueCurrentTriggerSession()
  }

  func trackDeferredTransaction() {
    transactionCount?.fail += 1

    activeTriggerSession?
      .transaction?
      .count = transactionCount

    activeTriggerSession?
      .transaction?
      .status = .fail

    activeTriggerSession?
      .transaction?
      .endAt = Date()
    enqueueCurrentTriggerSession()
  }

  func trackTransactionSucceeded(
    withId id: String?,
    for product: SKProduct,
    isFreeTrialAvailable: Bool
  ) {
    transactionCount?.complete += 1

    activeTriggerSession?
      .transaction?
      .count = transactionCount

    activeTriggerSession?
      .transaction?
      .id = id

    activeTriggerSession?
      .transaction?
      .endAt = Date()

    activeTriggerSession?
      .transaction?
      .status = .complete

    activeTriggerSession?
      .paywall?
      .action
      .convertedAt = Date()

    if product.subscriptionPeriod == nil {
      activeTriggerSession?
        .transaction?
        .outcome = .nonRecurringProductPurchase
    }

    if isFreeTrialAvailable {
      activeTriggerSession?
        .transaction?
        .outcome = .trialStart
    } else {
      activeTriggerSession?
        .transaction?
        .outcome = .subscriptionStart
    }
    enqueueCurrentTriggerSession()
  }
}
