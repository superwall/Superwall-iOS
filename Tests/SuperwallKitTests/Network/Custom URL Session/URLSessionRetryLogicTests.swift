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

  @Test(arguments: [200, 201, 204, 299])
  func isTerminal_successfulResponses(statusCode: Int) {
    #expect(!TaskRetryLogic.isTerminal(statusCode: statusCode))
  }

  /// A redirect only reaches us when `URLSession` couldn't follow it, and it will
  /// come back the same way every time, so there's nothing to gain from retrying.
  @Test(arguments: [301, 302, 303, 307, 308])
  func isTerminal_redirects(statusCode: Int) {
    #expect(TaskRetryLogic.isTerminal(statusCode: statusCode))
  }
}
