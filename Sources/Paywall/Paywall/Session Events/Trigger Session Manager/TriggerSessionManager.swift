//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/04/2022.
//
// swiftlint:disable type_body_length file_length

import UIKit
import StoreKit

final class TriggerSessionManager {
  weak var delegate: SessionEventsDelegate?

  /// Storage class. Can be injected via init for testing.
  private let storage: Storage

  /// Config Manager class. Can be injected via init for testing.
  private let configManager: ConfigManager

  /// The list of all potential trigger sessions, keyed by the trigger event name, created after receiving the config.
  private var pendingTriggerSessions: [String: TriggerSession] = [:]

  /// The active trigger session.
  var activeTriggerSession: TriggerSession?

  /// A local count for transactions used within the trigger session.
  private var transactionCount: TriggerSession.Transaction.Count?

  enum LoadState {
    case start
    case end
    case fail
  }

  /// Only instantiate this if you're testing. Otherwise use `SessionEvents.shared`.
  init(
    delegate: SessionEventsDelegate?,
    storage: Storage = .shared,
    configManager: ConfigManager = .shared
  ) {
    self.delegate = delegate
    self.storage = storage
    self.configManager = configManager
    addObservers()
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

  @objc private func applicationDidEnterBackground() {
    activeTriggerSession?.endAt = Date()
    enqueueCurrentTriggerSession()
  }

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
        configRequestId: configManager.configRequestId,
        userAttributes: IdentityManager.shared.userAttributes,
        isSubscribed: Paywall.shared.isUserSubscribed,
        eventName: trigger.eventName,
        appSession: AppSessionManager.shared.appSession
      )
      pendingTriggerSessions[trigger.eventName] = pendingTriggerSession
    }

    // Send the sessions back to the server.
    enqueuePendingTriggerSessions()
  }

  /// Active a pending trigger session.
  ///
  /// - Parameters:
  ///   - presentationInfo: Information about the paywall presentation.
  ///   - presentingViewController: What view the paywall will be presented on, if any.
  ///   - paywallResponse: The response from the server associated with the paywall
  func activateSession(
    for presentationInfo: PresentationInfo,
    on presentingViewController: UIViewController? = nil,
    paywallResponse: PaywallResponse? = nil,
    triggerResult: TriggerResult?,
    trackEvent: (Trackable) -> TrackingResult = Paywall.track
  ) {
    guard let eventName = presentationInfo.eventName else {
      // The paywall is being presented by identifier and that's not supported.
      return
    }

    if let triggerResult = triggerResult {
      let trackedEvent = InternalSuperwallEvent.TriggerFire(
        triggerResult: triggerResult,
        triggerName: eventName
      )
      _ = trackEvent(trackedEvent)
    }

    guard var session = pendingTriggerSessions[eventName] else {
      return
    }
    guard let outcome = TriggerSessionManagerLogic.outcome(
      presentationInfo: presentationInfo,
      presentingViewController: presentingViewController,
      paywallResponse: paywallResponse,
      triggerResult: triggerResult
    ) else {
      return
    }

    // Update trigger session
    session.userAttributes = JSON(IdentityManager.shared.userAttributes)
    session.presentationOutcome = outcome.presentationOutcome
    session.trigger = outcome.trigger
    session.paywall = outcome.paywall
    session.products = TriggerSession.Products(
      allProducts: paywallResponse?.swProducts ?? [],
      loadingInfo: .init(
        startAt: paywallResponse?.productsLoadStartTime,
        endAt: paywallResponse?.productsLoadCompleteTime,
        failAt: paywallResponse?.productsLoadFailTime
      )
    )

    session.appSession = AppSessionManager.shared.appSession

    self.activeTriggerSession = session
    pendingTriggerSessions[eventName] = nil

    switch outcome.presentationOutcome {
    case .holdout,
      .noRuleMatch:
      endSession()
    case .paywall:
      enqueueCurrentTriggerSession()
    }
  }

  /// Ends the active trigger session and resets it to `nil`.
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
      configRequestId: configManager.configRequestId,
      userAttributes: IdentityManager.shared.userAttributes,
      isSubscribed: Paywall.shared.isUserSubscribed,
      eventName: eventName,
      products: currentTriggerSession.products.allProducts,
      appSession: AppSessionManager.shared.appSession
    )
    pendingTriggerSessions[eventName] = pendingTriggerSession

    // Reset state of current trigger session
    transactionCount = nil
    activeTriggerSession = nil
  }

  /// Queues the trigger session to be sent back to the server.
  private func enqueueCurrentTriggerSession() {
    guard var triggerSession = activeTriggerSession else {
      return
    }

    triggerSession.isSubscribed = Paywall.shared.isUserSubscribed
    delegate?.enqueue(triggerSession)
  }

  /// Queues all the pending trigger sessions to be sent back to the server.
  private func enqueuePendingTriggerSessions() {
    for eventName in pendingTriggerSessions.keys {
      guard var pendingTriggerSession = pendingTriggerSessions[eventName] else {
        continue
      }
      pendingTriggerSession.isSubscribed = Paywall.shared.isUserSubscribed
      pendingTriggerSessions[eventName] = pendingTriggerSession
    }

    let triggerSessionsArray = Array(pendingTriggerSessions.values)
    delegate?.enqueue(triggerSessionsArray)
  }

  // MARK: - App Session

  /// Adds the latest app session to the trigger
  func updateAppSession(to appSession: AppSession) {
    activeTriggerSession?.appSession = appSession

    for eventName in pendingTriggerSessions.keys {
      var pendingTriggerSession = pendingTriggerSessions[eventName]
      pendingTriggerSession?.appSession = appSession
      pendingTriggerSessions[eventName] = pendingTriggerSession
    }

    enqueuePendingTriggerSessions()
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

  // MARK: - Webview Load

  /// Tracks when a webview started to load.
  func trackWebviewLoad(
    forPaywallId paywallId: String,
    state: LoadState
  ) {
    // Check the webview that's loading is for the active trigger session paywall.
    // Without this check preloading paywalls could intefere.
    guard paywallId == activeTriggerSession?.paywall?.databaseId else {
      return
    }
    switch state {
    case .start:
      activeTriggerSession?
        .paywall?
        .webviewLoading
        .startAt = Date()
    case .end:
      activeTriggerSession?
        .paywall?
        .webviewLoading
        .endAt = Date()
    case .fail:
      activeTriggerSession?
        .paywall?
        .webviewLoading
        .failAt = Date()
    }

    enqueueCurrentTriggerSession()
  }

  // MARK: - Paywall Response Load

  /// Tracks when a paywall started to load.
  func trackPaywallResponseLoad(
    forPaywallId paywallId: String?,
    state: LoadState
  ) {
    if paywallId == nil {
      return
    }

    // Otherwise, we check against the databaseId of the paywall
    guard paywallId == activeTriggerSession?.paywall?.databaseId else {
      return
    }

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

  /// Tracks when products started to load.
  func trackProductsLoad(
    forPaywallId paywallId: String,
    state: LoadState
  ) {
    guard paywallId == activeTriggerSession?.paywall?.databaseId else {
      return
    }
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

  // MARK: - Transactions

  func trackBeginTransaction(
    of product: SKProduct
  ) {
    // Determine local transaction count, per trigger session.
    if transactionCount != nil {
      transactionCount?.start += 1
    } else {
      transactionCount = .init(start: 1)
    }

    let productIndex = activeTriggerSession?
      .products
      .allProducts
      .firstIndex {
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

    activeTriggerSession?
      .transaction = nil
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

    activeTriggerSession?
      .transaction = nil
  }

  /// When a transaction is restored. A restore is triggered without any other transaction occurring.
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

    let productIndex = activeTriggerSession?
      .products
      .allProducts
      .firstIndex {
        $0.productIdentifier == product.productIdentifier
      } ?? 0

    let date = Date()
    transaction = .init(
      id: id,
      startAt: date,
      endAt: date,
      count: transactionCount,
      status: .complete,
      product: .init(from: product, index: productIndex)
    )

    activeTriggerSession?
      .transaction = transaction

    enqueueCurrentTriggerSession()

    activeTriggerSession?
      .transaction = nil
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

    activeTriggerSession?
      .transaction = nil
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

    let transactionOutcome = TriggerSessionManagerLogic.getTransactionOutcome(
      for: product,
      isFreeTrialAvailable: isFreeTrialAvailable
    )
    activeTriggerSession?
      .transaction?
      .outcome = transactionOutcome

    enqueueCurrentTriggerSession()

    activeTriggerSession?
      .transaction = nil
  }
}
