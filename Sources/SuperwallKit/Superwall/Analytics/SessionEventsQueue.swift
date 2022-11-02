//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/05/2022.
//

import UIKit
import Combine

/// A protocol that defines the internal methods for `SessionEventsQueue`.
///
/// This is used to be able to inject a mock version for testing.
protocol SessionEnqueuable: Actor {
  var triggerSessions: [TriggerSession] { get set }
  var transactions: [TransactionModel] { get }

  func enqueue(_ triggerSession: TriggerSession)
  func enqueue(_ triggerSessions: [TriggerSession])
  func enqueue(_ transaction: TransactionModel)
  func removeAllTriggerSessions()
  func flushInternal(depth: Int)
  func saveCacheToDisk()
}

extension SessionEnqueuable {
  /// Used for testing purposes only
  func removeAllTriggerSessions() {}
}

/// Sends n analytical events to the Superwall servers every 20 seconds, where n is defined by `maxEventCount`.
///
/// **Note**: this currently has a limit of 500 events per flush.
actor SessionEventsQueue: SessionEnqueuable {
  private let maxEventCount = 50
  var triggerSessions: [TriggerSession] = []
  var transactions: [TransactionModel] = []
  private var timer: AnyCancellable?
  @MainActor
  private var willResignActiveObserver: AnyCancellable?
  private lazy var lastTwentySessions = LimitedQueue<TriggerSession>(limit: 20)
  private lazy var lastTwentyTransactions = LimitedQueue<TransactionModel>(limit: 20)

  deinit {
    timer?.cancel()
    timer = nil
  }

  init() {
    Task {
      await setupTimer()
      await addObserver()
    }
  }

  private func setupTimer() {
    let timeInterval = Superwall.options.networkEnvironment == .release ? 20.0 : 1.0
    timer = Timer
      .publish(
        every: timeInterval,
        on: RunLoop.main,
        in: .default
      )
      .autoconnect()
      .sink { [weak self] _ in
        guard let self = self else {
          return
        }
        Task {
          await self.flushInternal(depth: 10)
        }
      }
  }

  @MainActor
  private func addObserver() {
    willResignActiveObserver = NotificationCenter.default
      .publisher(for: UIApplication.willResignActiveNotification)
      .sink { [weak self] _ in
        guard let self = self else {
          return
        }
        Task {
          await self.willResignActive()
        }
      }
  }

  private func willResignActive() async {
    flushInternal(depth: 10)
    saveCacheToDisk()
  }

  func enqueue(_ triggerSession: TriggerSession) {
    triggerSessions.append(triggerSession)
    lastTwentySessions.enqueue(triggerSession)
  }

  func enqueue(_ transaction: TransactionModel) {
    transactions.append(transaction)
    lastTwentyTransactions.enqueue(transaction)
  }

  func enqueue(_ triggerSessions: [TriggerSession]) {
    self.triggerSessions += triggerSessions

    for session in triggerSessions {
      lastTwentySessions.enqueue(session)
    }
  }

  func flushInternal(depth: Int) {
    var triggerSessionsToSend: [TriggerSession] = []
    var transactionsToSend: [TransactionModel] = []

    var i = 0
    while i < maxEventCount && !triggerSessions.isEmpty {
      triggerSessionsToSend.append(triggerSessions.removeFirst())
      i += 1
    }

    i = 0
    while i < maxEventCount && !transactions.isEmpty {
      transactionsToSend.append(transactions.removeFirst())
      i += 1
    }

    if !triggerSessionsToSend.isEmpty || !transactionsToSend.isEmpty {
      // Send to network
      let sessionEvents = SessionEventsRequest(
        triggerSessions: triggerSessionsToSend,
        transactions: transactionsToSend
      )
      Task {
        await Network.shared.sendSessionEvents(sessionEvents)
      }
    }

    if (!triggerSessions.isEmpty || !transactions.isEmpty) && depth > 0 {
      return flushInternal(depth: depth - 1)
    }
  }

  func saveCacheToDisk() {
    saveLatestSessionsToDisk()
    saveLatestTransactionsToDisk()
  }

  private func saveLatestSessionsToDisk() {
    let sessions = lastTwentySessions.getArray()
    Storage.shared.save(sessions, forType: TriggerSessions.self)
  }

  private func saveLatestTransactionsToDisk() {
    let transactions = lastTwentyTransactions.getArray()
    Storage.shared.save(transactions, forType: Transactions.self)
  }
}
