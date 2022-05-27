//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/05/2022.
//

import Foundation

protocol SessionEventsDelegate: AnyObject {
  var triggerSession: TriggerSessionManager { get }

  func enqueue(_ triggerSession: TriggerSession)
  func enqueue(_ triggerSessions: [TriggerSession])
  func enqueue(_ transaction: TransactionModel)
}

final class SessionEventsManager {
  /// The shared instance of the class
  static let shared = SessionEventsManager()

  /// The trigger session manager.
  lazy var triggerSession = TriggerSessionManager(delegate: self)

  /// The transaction manager.
  lazy var transactions = TransactionManager(delegate: self)

  /// A queue of trigger session events that get sent to the server.
  private let queue: SessionEventsQueue

  /// Network class. Can be injected via init for testing.
  private let network: Network

  /// Storage class. Can be injected via init for testing.
  private let storage: Storage

  /// Only instantiate this if you're testing. Otherwise use `SessionEvents.shared`.
  init(
    queue: SessionEventsQueue = SessionEventsQueue(),
    storage: Storage = Storage.shared,
    network: Network = Network.shared
  ) {
    self.queue = queue
    self.storage = storage
    self.network = network
    postCachedSessionEvents()
  }

  /// Gets the last 20 cached trigger sessions from the last time the app was terminated,
  /// sends them back to the server, then clears cache.
  private func postCachedSessionEvents() {
    let cachedTriggerSessions = storage.getCachedTriggerSessions()
    if cachedTriggerSessions.isEmpty {
      return
    }
    let sessionEvents = SessionEventsRequest(
      triggerSessions: cachedTriggerSessions,
      transactions: [] // TODO: cachedTransactions
    )
    network.sendSessionEvents(sessionEvents)
    storage.clearCachedTriggerSessions()
  }

  func updateAppSession(
    _ appSession: AppSession = AppSessionManager.shared.appSession
  ) {
    triggerSession.updateAppSession(to: appSession)
  }
}

// MARK: - SessionEventsDelegate
extension SessionEventsManager: SessionEventsDelegate {
  func enqueue(_ triggerSession: TriggerSession) {
    queue.enqueue(triggerSession)
  }

  func enqueue(_ triggerSessions: [TriggerSession]) {
    queue.enqueue(triggerSessions)
  }

  func enqueue(_ transaction: TransactionModel) {
    queue.enqueue(transaction)
  }
}
