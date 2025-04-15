//
//  MockSuperwallDelegate.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 31/03/2025.
//

import Testing
@testable import SuperwallKit

final class MockSuperwallDelegate: SuperwallDelegate {
  var receivedResult: RedemptionResult?
  var eventsReceived: [SuperwallEvent] = []

  func didRedeemLink(result: RedemptionResult) {
    receivedResult = result
  }

  func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
    eventsReceived.append(eventInfo.event)
  }
}
