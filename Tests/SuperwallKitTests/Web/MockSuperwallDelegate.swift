//
//  MockSuperwallDelegate.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 31/03/2025.
//

import Testing
import Foundation
@testable import SuperwallKit

final class MockSuperwallDelegate: SuperwallDelegate {
  var receivedResult: RedemptionResult?
  var eventsReceived: [SuperwallEvent] = []
  var receivedUserAttributes: [String: Any]?
  var willRedeemCallCount = 0
  var willRedeemCalledAt: Date?
  var didRedeemCalledAt: Date?

  func didRedeemLink(result: RedemptionResult) {
    receivedResult = result
    didRedeemCalledAt = Date()
  }

  func willRedeemLink() {
    willRedeemCallCount += 1
    willRedeemCalledAt = Date()
  }

  func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
    eventsReceived.append(eventInfo.event)
  }

  func userAttributesDidChange(newAttributes: [String: Any]) {
    receivedUserAttributes = newAttributes
  }
}
