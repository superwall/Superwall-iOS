//
//  File.swift
//  
//
//  Created by Yusuf Tör on 18/05/2022.
//

import Foundation
@testable import Paywall

final class SessionEventsQueueMock: SessionEventsQueue {
  var triggerSessions: [TriggerSession] = []
  var transactions: [TransactionModel] = []

  override func enqueue(_ triggerSession: TriggerSession) {
    triggerSessions.append(triggerSession)
  }

  override func enqueue(_ triggerSessions: [TriggerSession]) {
    self.triggerSessions += triggerSessions
  }

  override func enqueue(_ transaction: TransactionModel) {
    self.transactions.append(transaction)
  }
}
