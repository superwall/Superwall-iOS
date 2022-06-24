//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/05/2022.
//

import UIKit
@testable import Paywall

final class NetworkMock: Network {
  var sentSessionEvents: SessionEventsRequest?
  var getConfigCalled = false

  override func sendSessionEvents(_ session: SessionEventsRequest) {
    sentSessionEvents = session
  }

  override func getConfig(
    withRequestId requestId: String,
    completion: @escaping (Result<Config, Error>) -> Void,
    applicationState: UIApplication.State = UIApplication.shared.applicationState,
    storage: Storage = Storage.shared
  ) {
    getConfigCalled = true
  }
}
