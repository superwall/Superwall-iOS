//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/10/2022.
//

import Foundation
@testable import Superwall

final class SessionEventsDelegateMock: SessionEventsDelegate {
  var triggerSession = TriggerSessionManager(delegate: nil)

  var queue: SessionEnqueuable

  init(queue: SessionEnqueuable) {
    self.queue = queue
  }

  func enqueue(_ triggerSession: TriggerSession) async {
    await queue.enqueue(triggerSession)
  }

  func enqueue(_ triggerSessions: [TriggerSession]) async {
    await queue.enqueue(triggerSessions)
  }

  func enqueue(_ transaction: TransactionModel) async {
    await queue.enqueue(transaction)
  }
}
