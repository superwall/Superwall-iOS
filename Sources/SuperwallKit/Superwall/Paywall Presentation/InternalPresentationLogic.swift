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
    shouldIgnoreSubscriptionStatus: Bool?,
    presentationCondition: PresentationCondition? = nil
  ) -> Bool {
    if isDebuggerLaunched {
      return false
    }

    func checkSubscriptionStatus() -> Bool {
      guard isUserSubscribed else {
        return false
      }
      if shouldIgnoreSubscriptionStatus ?? false {
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

  static func presentationError(
    domain: String,
    code: Int,
    title: String,
    value: String
  ) -> NSError {
    let userInfo: [String: Any] = [
      NSLocalizedDescriptionKey: NSLocalizedString(title, value: value, comment: "")
    ]
    return NSError(
      domain: domain,
      code: code,
      userInfo: userInfo
    )
  }
}
