//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/05/2022.
//

import Foundation
@testable import Paywall

final class SessionEventsDelegateMock: SessionEventsDelegate {
  func enqueue(_ triggerSession: TriggerSession) {

  }

  func enqueue(_ triggerSessions: [TriggerSession]) {

  }

  func enqueue(_ transaction: TransactionModel) {

  }

  var triggerSession: TriggerSessionManager {
    didSet {
      
    }
  }
}
