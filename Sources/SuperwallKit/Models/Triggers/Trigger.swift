//
//  Trigger.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct Trigger: Codable, Hashable {
  var eventName: String
  var rules: [TriggerRule]
}

extension Trigger: Stubbable {
  static func stub() -> Trigger {
    return Trigger(
      eventName: "an_event",
      rules: []
    )
  }
}
