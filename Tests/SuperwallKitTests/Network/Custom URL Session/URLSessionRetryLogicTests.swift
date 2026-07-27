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

  @Test(arguments: [400, 401, 403, 404, 405, 410, 422])
  func isTerminal_clientErrors(statusCode: Int) {
    #expect(TaskRetryLogic.isTerminal(statusCode: statusCode))
  }

  @Test(arguments: [408, 425, 429, 499])
  func isTerminal_retryableClientErrors(statusCode: Int) {
    #expect(!TaskRetryLogic.isTerminal(statusCode: statusCode))
  }

  @Test(arguments: [500, 502, 503, 504])
  func isTerminal_serverErrors(statusCode: Int) {
    #expect(!TaskRetryLogic.isTerminal(statusCode: statusCode))
  }

  @Test(arguments: [200, 201, 204, 301, 304])
  func isTerminal_nonErrors(statusCode: Int) {
    #expect(!TaskRetryLogic.isTerminal(statusCode: statusCode))
  }
}
