//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/05/2022.
//
// swiftlint:disable all

import Foundation
@testable import Paywall

final class SessionEventsDelegateMock: SessionEventsDelegate {
  var triggerSession = TriggerSessionManager(delegate: nil)
  var queue: SessionEventsQueue

  init(queue: SessionEventsQueue) {
    self.queue = queue
  }

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
