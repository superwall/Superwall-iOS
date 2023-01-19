//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/10/2022.
//

import Foundation
@testable import SuperwallKit

final class SessionEventsDelegateMock: SessionEventsDelegate {
  var queue: SessionEnqueuable
  var triggerSession: TriggerSessionManager!

  init(
    queue: SessionEnqueuable,
    factory: TriggerSessionManagerFactory
  ) {
    self.queue = queue
    self.triggerSession = factory.makeTriggerSessionManager()
  }

  func enqueue(_ triggerSession: TriggerSession) async {
    await queue.enqueue(triggerSession)
  }

  func enqueue(_ triggerSessions: [TriggerSession]) async {
    await queue.enqueue(triggerSessions)
  }

  func enqueue(_ transaction: StoreTransaction) async {
    await queue.enqueue(transaction)
  }
}
