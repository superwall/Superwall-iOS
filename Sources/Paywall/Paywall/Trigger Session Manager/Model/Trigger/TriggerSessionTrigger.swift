//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension TriggerSession {
  struct Trigger: Encodable {
    /// The trigger event data
    let eventData: EventData

    enum TriggerType: String, Encodable {
      case implicit
      case explicit
    }
    /// The type of the trigger
    let type: TriggerType

    /// Information about the object that the paywall is being presented on, if any.
    let presentedOn: String?

      /// The presenting class name
    var experiment: Experiment?

    enum CodingKeys: String, CodingKey {
      case params = "paywall_trigger_event_params"
      case eventId = "paywall_trigger_event_id"
      case name = "paywall_trigger_event_name"
      case createdAt = "paywall_trigger_event_ts"
      case type = "paywall_trigger_trigger_type"
      case presentedOn = "paywall_trigger_presented_on"
    }

    func encode(to encoder: Encoder) throws {
      // TODO: There's no trigger_id here, do we actually have that or is that on server?
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(eventData.id, forKey: .eventId)
      try container.encode(eventData.name, forKey: .name)
      try container.encode(eventData.parameters, forKey: .params)
      try container.encode(eventData.createdAt, forKey: .createdAt)
      try container.encode(type, forKey: .type)
      try container.encodeIfPresent(presentedOn, forKey: .presentedOn)

      try experiment.encode(to: encoder)
    }
  }
}
