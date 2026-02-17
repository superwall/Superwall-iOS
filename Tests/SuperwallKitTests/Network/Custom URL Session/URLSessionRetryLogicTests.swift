//
//  File.swift
//
//
//  Created by Yusuf Tör on 23/06/2022.
//
// swiftlint:disable all

import Testing
@testable import SuperwallKit

struct URLSessionRetryLogicTests {
  @Test func delay_lastAttempt() {
    let delay = TaskRetryLogic.delay(
      forAttempt: 6,
      maxRetries: 6
    )!
    let twentySixSeconds = UInt64(26_000_000_000)

    #expect(UInt64(delay/1000) <= twentySixSeconds)
  }

  @Test func delay_tooManyAttempts() {
    let delay = TaskRetryLogic.delay(
      forAttempt: 7,
      maxRetries: 6
    )
    #expect(delay == nil)
  }
}
