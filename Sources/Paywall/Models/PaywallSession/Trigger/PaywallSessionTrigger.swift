//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension PaywallSession {
  struct Trigger: Encodable {
    /// The ID of the trigger in the database
    let id: String

    /// The SDK generated ID of the event trigger
    let eventId: String

    /// The name of the trigger, e.g. `app_open`
    let name: String
    
    enum TriggerType: String, Encodable {
      case implicit
      case explicit
    }
    /// The type of the trigger
    let type: TriggerType

    /// If the trigger came from a Superwall event
    let isSuperwallEvent: Bool

    /// The experiment associated with the trigger
    let experiment: Experiment

    enum CodingKeys: String, CodingKey {
      case id = "trigger_id"
      case eventId = "trigger_event_id"
      case name = "trigger_name"
      case type = "trigger_type"
      case isSuperwallEvent = "is_superwall_event_trigger"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(id, forKey: .id)
      try container.encode(eventId, forKey: .eventId)
      try container.encode(name, forKey: .name)
      try container.encode(type, forKey: .type)
      try container.encode(isSuperwallEvent, forKey: .isSuperwallEvent)

      try experiment.encode(to: encoder)

    }
  }
}
