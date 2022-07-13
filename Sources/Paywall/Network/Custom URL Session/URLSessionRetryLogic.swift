//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//

import Foundation

enum URLSessionRetryLogic {
  private static let maxRetries = 6.0

  static func delay(forAttempt attempt: Double) -> Int? {
    guard attempt <= URLSessionRetryLogic.maxRetries else {
      return nil
    }
    let jitter = Double.random(in: 0..<1)
    let initialDelay = 5.0
    let multiplier = 1.0
    let attemptRatio = attempt / maxRetries
    let delay = pow(initialDelay, (multiplier + attemptRatio)) + jitter
    let millisecondDelay = Int(delay * 1000)
    return millisecondDelay
  }
}
