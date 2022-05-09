//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension TriggerSession {
  struct Trigger: Codable {
    /// The trigger event data
    let eventData: EventData

    enum TriggerType: String, Codable {
      case implicit = "IMPLICIT"
      case explicit = "EXPLICIT"
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
      case presentedOn = "paywall_trigger_presented_on_description"
    }

    init(
      eventData: EventData,
      type: TriggerType,
      presentedOn: String?,
      experiment: Experiment? = nil
    ) {
      self.eventData = eventData
      self.type = type
      self.presentedOn = presentedOn
      self.experiment = experiment
    }

    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      let eventId = try values.decode(String.self, forKey: .eventId)
      let name = try values.decode(String.self, forKey: .name)
      let params = try values.decode(JSON.self, forKey: .params)
      let createdAt = try values.decode(String.self, forKey: .createdAt)
      eventData = EventData(
        id: eventId,
        name: name,
        parameters: params,
        createdAt: createdAt
      )
      type = try values.decode(TriggerType.self, forKey: .type)
      presentedOn = try values.decodeIfPresent(String.self, forKey: .presentedOn)

      experiment = try? Experiment(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(eventData.id, forKey: .eventId)
      try container.encode(eventData.name, forKey: .name)
      try container.encode(eventData.parameters, forKey: .params)
      try container.encode(eventData.createdAt, forKey: .createdAt)
      try container.encode(type, forKey: .type)
      try container.encodeIfPresent(presentedOn, forKey: .presentedOn)

      try experiment?.encode(to: encoder)
    }
  }
}
