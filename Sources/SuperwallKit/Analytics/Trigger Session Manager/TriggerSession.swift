//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

/// This represents the possibilty of a trigger being fired.
struct TriggerSession: Encodable {
  enum PresentationOutcome: String, Encodable {
    case paywall = "PAYWALL"
    case holdout = "HOLDOUT"
    case noRuleMatch = "NO_RULE_MATCH"
  }

  /// Trigger session ID
  let id = UUID().uuidString

  /// The name of the event that activated the trigger session.
  let eventName: String
}

extension TriggerSession: Stubbable {
  static func stub() -> TriggerSession {
    return TriggerSession(
      eventName: "abc"
    )
  }
}
