//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//

import Foundation

enum TaskRetryLogic {
  static func delay(
    forAttempt attempt: Int,
    maxRetries: Int
  ) -> UInt64? {
    guard attempt <= maxRetries else {
      return nil
    }
    let jitter = Double.random(in: 0..<1)
    let initialDelay = 5.0
    let multiplier = 1.0
    let attemptRatio = Double(attempt) / Double(maxRetries)
    let delay = pow(initialDelay, (multiplier + attemptRatio)) + jitter
    let oneSecond = TimeInterval(1_000_000_000)
    return UInt64(oneSecond * delay)
  }

  /// Client error codes that may still succeed if the request is sent again.
  private static let retryableClientErrorCodes: Set<Int> = [
    408, // Request Timeout
    425, // Too Early
    429, // Too Many Requests
    499  // Client Closed Request
  ]

  /// Whether a response with this status code will never succeed on retry.
  ///
  /// Server errors (5xx) and the retryable client errors above are worth sending
  /// again. Everything else outside the 2xx range returns the same result however
  /// many times it's sent, including a redirect that reached us because it couldn't
  /// be followed.
  static func isTerminal(statusCode: Int) -> Bool {
    if (200...299).contains(statusCode) {
      return false
    }
    if (500...599).contains(statusCode) {
      return false
    }
    return !retryableClientErrorCodes.contains(statusCode)
  }
}
