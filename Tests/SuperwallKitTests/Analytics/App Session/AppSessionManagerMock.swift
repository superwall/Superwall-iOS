//
//  File.swift
//  
//
//  Created by Yusuf Tör on 31/05/2022.
//

import Foundation
@testable import SuperwallKit

class AppManagerDelegateMock: AppManagerDelegate, DeviceHelperFactory, UserAttributesEventFactory {
  func makeDeviceInfo() -> SuperwallKit.DeviceInfo {
    return .init(appInstalledAtString: "", locale: "")
  }
  func makeIsSandbox() -> Bool { return true}
  func makeSessionDeviceAttributes() async -> [String : Any] { [:] }
  func makeUserAttributesEvent() -> InternalSuperwallEvent.Attributes { 
    return InternalSuperwallEvent.Attributes(appInstalledAtString: "")
  }

  func didUpdateAppSession(_ appSession: AppSession) async {}
}

final class AppSessionManagerMock: AppSessionManager {
  var internalAppSession: AppSession
  override var appSession: AppSession {
    return internalAppSession
  }

  init(
    appSession: AppSession,
    identityManager: IdentityManager,
    configManager: ConfigManager,
    storage: Storage
  ) {
    internalAppSession = appSession
    super.init(
      configManager: configManager,
      identityManager: identityManager,
      storage: storage,
      delegate: AppManagerDelegateMock()
    )
  }

  override func listenForAppSessionTimeout() {
    // Overriding so we don't get ny issues when setting config manually.
  }
}
