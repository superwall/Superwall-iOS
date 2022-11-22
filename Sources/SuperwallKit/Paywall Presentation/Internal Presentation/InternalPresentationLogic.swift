//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//

import Foundation

enum InternalPresentationLogic {
  /// Checks for paywall presentation overrides before checking the user's subscription
  /// status to determine whether or not to show the paywall.
  ///
  /// - Returns: A boolean that is `true` when the paywall should NOT be presented.
  static func shouldNotPresentPaywall(
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
