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
}
