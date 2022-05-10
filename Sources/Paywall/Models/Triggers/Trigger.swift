//
//  Trigger.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct Trigger: Decodable, Hashable {
  var eventName: String
  var rules: [TriggerRule]

  init(
    eventName: String,
    rules: [TriggerRule]
  ) {
    self.eventName = eventName
    self.rules = rules
  }
}

extension Trigger: Stubbable {
  static func stub() -> Trigger {
    return Trigger(
      eventName: "an_event",
      rules: []
    )
  }
}
