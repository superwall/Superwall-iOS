//
//  File.swift
//  
//
//  Created by Yusuf Tör on 31/05/2022.
//

import Foundation
@testable import SuperwallKit

class AppManagerDelegateMock: AppManagerDelegate {
  func didUpdateAppSession(_ appSession: AppSession) async {}
}

final class AppSessionManagerMock: AppSessionManager {
  var internalAppSession: AppSession
  override var appSession: AppSession {
    return internalAppSession
  }

  init(
    appSession: AppSession,
    configManager: ConfigManager,
    storage: Storage
  ) {
    internalAppSession = appSession
    super.init(configManager: configManager, storage: storage, delegate: AppManagerDelegateMock())
  }

  override func listenForAppSessionTimeout() {
    // Overriding so we don't get ny issues when setting config manually.
  }
}
