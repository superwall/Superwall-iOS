//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/05/2022.
//

import UIKit

/// Sends n analytical events to the Superwall servers every 20 seconds, where n is defined by `maxEventCount`.
///
/// **Note**: this currently has a limit of 500 events per flush.
class SessionEventsQueue {
  private let serialQueue = DispatchQueue(label: "me.superwall.sessionEventQueue")
  private let maxEventCount = 50
  private var triggerSessions: [TriggerSession] = []
  private var transactions: [TransactionModel] = []
  private var timer: Timer?
  private lazy var lastTwentySessions = LimitedQueue<TriggerSession>(limit: 20)
  private lazy var lastTwentyTransactions = LimitedQueue<TransactionModel>(limit: 20)

  deinit {
    timer?.invalidate()
    timer = nil
    NotificationCenter.default.removeObserver(self)
  }

  init() {
    let timeInterval = Paywall.networkEnvironment == .release ? 20.0 : 1.0
    timer = Timer.scheduledTimer(
      timeInterval: timeInterval,
      target: self,
      selector: #selector(flush),
      userInfo: nil,
      repeats: true
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(flush),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(saveCacheToDisk),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
  }

  func enqueue(_ triggerSession: TriggerSession) {
    serialQueue.async { [weak self] in
      guard let self = self else {
        return
      }
      self.triggerSessions.append(triggerSession)
      self.lastTwentySessions.enqueue(triggerSession)
    }
  }

  func enqueue(_ transaction: TransactionModel) {
    serialQueue.async { [weak self] in
      guard let self = self else {
        return
      }
      self.transactions.append(transaction)
      self.lastTwentyTransactions.enqueue(transaction)
    }
  }

  func enqueue(_ triggerSessions: [TriggerSession]) {
    serialQueue.async { [weak self] in
      guard let self = self else {
        return
      }
      self.triggerSessions += triggerSessions

      for session in triggerSessions {
        self.lastTwentySessions.enqueue(session)
      }
    }
  }

  @objc private func flush() {
    serialQueue.async {
      self.flushInternal()
    }
  }

  private func flushInternal(depth: Int = 10) {
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
      Network.shared.sendSessionEvents(sessionEvents)
    }

    if (!triggerSessions.isEmpty || !transactions.isEmpty) && depth > 0 {
      return flushInternal(depth: depth - 1)
    }
  }

  @objc private func saveCacheToDisk() {
    saveLatestSessionsToDisk()
    saveLatestTransactionsToDisk()
  }

  private func saveLatestSessionsToDisk() {
    let sessions = lastTwentySessions.getArray()
    Storage.shared.saveTriggerSessions(sessions)
  }

  private func saveLatestTransactionsToDisk() {
    let transactions = lastTwentyTransactions.getArray()
    Storage.shared.saveTransactions(transactions)
  }
}
