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
  /// The shared instance of the class
  static let shared = TriggerSessionManager()

  /// A queue of trigger session events that get sent to the server.
  private let queue: SessionEventsQueue

  /// Storage class. Can be injected via init for testing.
  private let storage: Storage

  /// Network class. Can be injected via init for testing.
  private let network: Network

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

  /// Only instantiate this if you're testing. Otherwise use `TriggerSessionManager.shared`.
  init(
    queue: SessionEventsQueue = SessionEventsQueue(),
    storage: Storage = Storage.shared,
    network: Network = Network.shared
  ) {
    self.queue = queue
    self.storage = storage
    self.network = network
    postCachedTriggerSessions()
    addObservers()
  }

  /// Gets the last 20 cached trigger sessions from the last time the app was terminated,
  /// sends them back to the server, then clears cache.
  private func postCachedTriggerSessions() {
    let cachedTriggerSessions = storage.getCachedTriggerSessions()
    if cachedTriggerSessions.isEmpty {
      return
    }
    let sessionEvents = SessionEventsRequest(
      triggerSessions: cachedTriggerSessions
    )
    network.sendSessionEvents(sessionEvents)
    storage.clearCachedTriggerSessions()
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

  // TODO: be sure to test what happens during a transaction, as app leaves foreground in that scenario
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
        configRequestId: storage.configRequestId,
        userAttributes: storage.userAttributes,
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
      configRequestId: storage.configRequestId,
      userAttributes: storage.userAttributes,
      isSubscribed: Paywall.delegate?.isUserSubscribed() ?? false,
      eventName: defaultEventName,
      products: StoreKitManager.shared.swProducts,
      appSession: AppSessionManager.shared.appSession
    )
    pendingTriggerSessions[defaultEventName] = defaultPaywallSession

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
    triggers: [String: Trigger] = Storage.shared.triggers
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
      paywallResponse: paywallResponse,
      triggers: triggers
    ) else {
      return
    }

    // Update trigger session
    session.userAttributes = JSON(storage.userAttributes)
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
      configRequestId: storage.configRequestId,
      userAttributes: storage.userAttributes,
      isSubscribed: Paywall.delegate?.isUserSubscribed() ?? false,
      eventName: eventName,
      products: StoreKitManager.shared.swProducts,
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
    triggerSession.isSubscribed = Paywall.delegate?.isUserSubscribed() ?? false
    queue.enqueue(triggerSession)
  }

  /// Queues all the pending trigger sessions to be sent back to the server.
  private func enqueuePendingTriggerSessions() {
    for eventName in pendingTriggerSessions.keys {
      guard var pendingTriggerSession = pendingTriggerSessions[eventName] else {
        continue
      }
      pendingTriggerSession.isSubscribed = Paywall.delegate?.isUserSubscribed() ?? false
      pendingTriggerSessions[eventName] = pendingTriggerSession
    }

    let triggerSessionsArray = Array(pendingTriggerSessions.values)
    queue.enqueue(triggerSessionsArray)
  }

  // MARK: - App Session

  /// Adds the latest app session to the trigger
  func updateAppSession(
    _ appSession: AppSession = AppSessionManager.shared.appSession
  ) {
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
      // If there isn't a paywallId, it means it's started loading the default paywall.
      // The only way we can check that is via checking the eventName.
      let eventName = SuperwallEvent.ManualPresent().rawName
      guard activeTriggerSession?.trigger.eventName == eventName else {
        return
      }
    } else {
      // Otherwise, we check against the databaseId of the paywall
      guard paywallId == activeTriggerSession?.paywall?.databaseId else {
        return
      }
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

  func storeAllProducts(_ products: [SWProduct]) {
    activeTriggerSession?
      .products
      .allProducts = products
    enqueueCurrentTriggerSession()
  }

  // MARK: - Transactions

  func trackBeginTransaction(
    of product: SKProduct,
    allProducts: [SWProduct] = StoreKitManager.shared.swProducts
  ) {
    // Determine local transaction count, per trigger session.
    if transactionCount != nil {
      transactionCount?.start += 1
    } else {
      transactionCount = .init(start: 1)
    }

    let productIndex = allProducts.firstIndex {
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
    isFreeTrialAvailable: Bool,
    allProducts: [SWProduct] = StoreKitManager.shared.swProducts
  ) {
    if transactionCount != nil {
      transactionCount?.restore += 1
    } else {
      transactionCount = .init(restore: 1)
    }

    var transaction: TriggerSession.Transaction

    let productIndex = allProducts.firstIndex {
      $0.productIdentifier == product.productIdentifier
    } ?? 0
    transaction = .init(
      id: id,
      startAt: Date(),
      endAt: Date(),
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
