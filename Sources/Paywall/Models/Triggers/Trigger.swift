//
//  Trigger.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct Trigger: Decodable, Hashable {
  var eventName: String
  var triggerVersion: TriggerVersion

  enum Keys: String, CodingKey {
    case eventName
    case triggerVersion
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: Trigger.Keys.self)
    eventName = try values.decode(String.self, forKey: .eventName)

    let triggerVersionString = try values.decode(String.self, forKey: .triggerVersion)
    switch triggerVersionString {
    case "V2":
      triggerVersion = .v2(try TriggerV2.init(from: decoder))
    default:
      triggerVersion = .v1
    }
  }

  init(
    eventName: String,
    triggerVersion: TriggerVersion
  ) {
    self.eventName = eventName
    self.triggerVersion = triggerVersion
  }
}

extension Trigger: Stubbable {
  static func stub() -> Trigger {
    return Trigger(
      eventName: "an_event",
      triggerVersion: .v1
    )
  }
}
