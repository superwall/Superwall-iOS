//
//  EventsRequest.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct EventsRequest: Encodable {
  var events: [JSON]

  /// What the logs say about this request: the event count and names, never
  /// the parameters. Logs reach the app's logging delegate, and parameters can
  /// hold a push token or the device's IP addresses.
  var loggableSummary: [String: Any] {
    return [
      "event_count": events.count,
      "event_names": events.map { $0["event_name"].string ?? "unknown" }
    ]
  }
}
