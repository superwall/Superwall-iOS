//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/08/2022.
//

import Foundation
@testable import Paywall

final class TriggerDelayManagerMock: TriggerDelayManager {
  var aboutToHandleDelayedContent: (() -> Void)?
  var didFireDelayedTriggers = false
  var didClearPreConfigTriggers = false

  override func handleDelayedContent(
    storage: Storage = .shared,
    configManager: ConfigManager = .shared
  ) {
    aboutToHandleDelayedContent?()
    super.handleDelayedContent(storage: storage, configManager: configManager)
  }

  override func fireDelayedTriggers(storage: Storage = .shared, paywall: Paywall = .shared) {
    didFireDelayedTriggers = true
  }

  override func clearPreConfigTriggers() {
    didClearPreConfigTriggers = true
  }
}
