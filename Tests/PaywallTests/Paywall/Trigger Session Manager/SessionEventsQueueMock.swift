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

  override func enqueue(_ triggerSession: TriggerSession) {
    triggerSessions.append(triggerSession)
  }

  override func enqueue(_ triggerSessions: [TriggerSession]) {
    self.triggerSessions += triggerSessions
  }
}
