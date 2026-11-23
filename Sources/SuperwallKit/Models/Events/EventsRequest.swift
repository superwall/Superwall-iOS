//
//  EventsRequest.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct EventsRequest: Encodable {
  var events: [JSON]

  /// The request as it's logged, without the parameters of the events that are
  /// only for Superwall. Logs reach the app's logging delegate.
  var redactedForLogs: EventsRequest {
    let events = events.map { event -> JSON in
      guard
        let name = event["event_name"].string,
        PrivateSuperwallEvent.names.contains(name)
      else {
        return event
      }
      var event = event
      event["parameters"] = JSON(CustomURLSession.redactedValue)
      return event
    }
    return EventsRequest(events: events)
  }
}
