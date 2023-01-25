//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//
// swiftlint:disable nesting

import Foundation

extension TriggerSession {
  struct Trigger: Codable {
    /// The trigger event data
    var eventId: String?

    /// The name of the event
    var eventName: String

    /// Parameters associated with the event
    var eventParameters: JSON?

    /// When the event was created
    var eventCreatedAt: Date?

    enum TriggerType: String, Codable {
      case implicit = "IMPLICIT"
      case explicit = "EXPLICIT"
    }
    /// The type of the trigger
    var type: TriggerType?

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
      eventId: String? = nil,
      eventName: String,
      eventParameters: JSON? = nil,
      eventCreatedAt: Date? = nil,
      type: TriggerType? = nil,
      presentedOn: String? = nil,
      experiment: Experiment? = nil
    ) {
      self.eventId = eventId
      self.eventName = eventName
      self.eventParameters = eventParameters
      self.eventCreatedAt = eventCreatedAt
      self.type = type
      self.presentedOn = presentedOn
      self.experiment = experiment
    }

    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      eventName = try values.decode(String.self, forKey: .name)

      eventId = try values.decodeIfPresent(String.self, forKey: .eventId)
      eventParameters = try values.decodeIfPresent(JSON.self, forKey: .params)
      eventCreatedAt = try values.decodeIfPresent(Date.self, forKey: .createdAt)
      type = try values.decodeIfPresent(TriggerType.self, forKey: .type)
      presentedOn = try values.decodeIfPresent(String.self, forKey: .presentedOn)

      experiment = try? Experiment(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(eventName, forKey: .name)

      try container.encodeIfPresent(eventId, forKey: .eventId)
      try container.encodeIfPresent(eventParameters, forKey: .params)
      try container.encodeIfPresent(eventCreatedAt, forKey: .createdAt)
      try container.encodeIfPresent(type, forKey: .type)
      try container.encodeIfPresent(presentedOn, forKey: .presentedOn)

      try experiment?.encode(to: encoder)
    }
  }
}

extension TriggerSession.Trigger: Stubbable {
  static func stub() -> TriggerSession.Trigger {
    return TriggerSession.Trigger(eventName: "abc")
  }
}
