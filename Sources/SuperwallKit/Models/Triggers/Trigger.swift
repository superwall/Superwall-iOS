//
//  Trigger.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct Trigger: Decodable, Hashable {
  var placementName: String
  var rules: [TriggerRule]
}

extension Trigger: Stubbable {
  static func stub() -> Trigger {
    return Trigger(
      placementName: "campaign_trigger",
      rules: []
    )
  }
}
