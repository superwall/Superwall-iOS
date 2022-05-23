//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/05/2022.
//

import Foundation
@testable import Paywall

final class StorageMock: Storage {
  var internalCachedTriggerSessions: [TriggerSession]
  var didClearCachedTriggerSessions = false

  init(internalCachedTriggerSessions: [TriggerSession]) {
    self.internalCachedTriggerSessions = internalCachedTriggerSessions
  }

  override func getCachedTriggerSessions() -> [TriggerSession] {
    return internalCachedTriggerSessions
  }

  override func clearCachedTriggerSessions() {
    didClearCachedTriggerSessions = true
  }
}
