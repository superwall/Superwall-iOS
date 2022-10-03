//
//  EventData.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

/// Data associated with an event. This could be any sort of event (user initiated, superwall), which may or may not trigger a paywall.
struct EventData: Codable, Equatable {
  /// SDK generated ID for event
  var id = UUID().uuidString

  /// The name of the event
  var name: String

  /// Parameters associated with the event
  var parameters: JSON

  /// When the event was created
  var createdAt: Date

  /// A `JSON` version of `EventData`
  var jsonData: JSON {
    return [
      "event_id": JSON(id),
      "event_name": JSON(name),
      "parameters": parameters,
      "created_at": JSON(createdAt.isoString)
    ]
  }
}

extension EventData: Stubbable {
  static func stub() -> EventData {
    return EventData(
      name: "opened_application",
      parameters: [:],
      createdAt: Date()
    )
  }
}
