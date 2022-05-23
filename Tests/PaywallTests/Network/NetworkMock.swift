//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/05/2022.
//

import Foundation
@testable import Paywall

final class NetworkMock: Network {
  var didSendSessionEvents = false

  override func sendSessionEvents(_ session: SessionEventsRequest) {
    didSendSessionEvents = true
  }
}
