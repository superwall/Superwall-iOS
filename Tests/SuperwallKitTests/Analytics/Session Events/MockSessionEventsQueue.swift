//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/10/2022.
//

import Foundation
@testable import SuperwallKit

actor MockSessionEventsQueue: SessionEnqueuable {
  var triggerSessions: [TriggerSession] = []
  var transactions: [StoreTransaction] = []

  func enqueue(_ triggerSession: TriggerSession) {
    debugPrint("trigger sesss", triggerSession)
    triggerSessions.append(triggerSession)
  }

  func enqueue(_ triggerSessions: [TriggerSession]) {
    self.triggerSessions += triggerSessions
  }

  func enqueue(_ transaction: StoreTransaction) {
    transactions.append(transaction)
  }

  func flushInternal(depth: Int) {}

  func saveCacheToDisk() {}

  func removeAllTriggerSessions() {
    triggerSessions.removeAll()
  }
}
