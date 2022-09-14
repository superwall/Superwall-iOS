//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//

import Foundation

enum InternalPresentationLogic {
  static func shouldNotDisplayPaywall(
    isUserSubscribed: Bool,
    isDebuggerLaunched: Bool,
    shouldIgnoreSubscriptionStatus: Bool,
    presentationCondition: PresentationCondition? = nil
  ) -> Bool {
    if isDebuggerLaunched {
      return false
    }

    func checkSubscriptionStatus() -> Bool {
      guard isUserSubscribed else {
        return false
      }
      if shouldIgnoreSubscriptionStatus {
        return false
      }
      return true
    }

    guard let presentationCondition = presentationCondition else {
      return checkSubscriptionStatus()
    }

    if presentationCondition == .always {
      return false
    }

    return checkSubscriptionStatus()
  }
}
