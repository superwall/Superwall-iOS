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
  /// Only client errors are terminal. Server errors (5xx) and the retryable client
  /// errors above are worth sending again.
  static func isTerminal(statusCode: Int) -> Bool {
    guard (400...499).contains(statusCode) else {
      return false
    }
    return !retryableClientErrorCodes.contains(statusCode)
  }
}
