//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/05/2022.
//

import Foundation
@testable import Paywall

final class NetworkMock: Network {
  var sentSessionEvents: SessionEventsRequest?

  override func sendSessionEvents(_ session: SessionEventsRequest) {
    sentSessionEvents = session
  }
}
