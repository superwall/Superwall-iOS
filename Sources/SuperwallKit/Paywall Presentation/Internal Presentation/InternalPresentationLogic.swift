//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/07/2022.
//

import Foundation

enum InternalPresentationLogic {
  struct UserSubscriptionOverrides {
    let isDebuggerLaunched: Bool
    let shouldIgnoreSubscriptionStatus: Bool?
    var presentationCondition: PresentationCondition?
  }
  /// Returns a booleans indicating whether the user is subscribed and their subscription status
  /// hasn't been overridden by the provided arguments.
  ///
  /// - Returns: A boolean that is `true` when the user is subscribed and their subscription
  /// status hasn't been overridden.
  static func userSubscribedAndNotOverridden(
    isUserSubscribed: Bool,
    overrides: UserSubscriptionOverrides
  ) -> Bool {
    if overrides.isDebuggerLaunched {
      return false
    }

    func checkSubscriptionStatus() -> Bool {
      guard isUserSubscribed else {
        return false
      }
      if overrides.shouldIgnoreSubscriptionStatus ?? false {
        return false
      }
      return true
    }

    guard let presentationCondition = overrides.presentationCondition else {
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
