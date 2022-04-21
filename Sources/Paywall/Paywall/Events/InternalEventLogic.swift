//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/04/2022.
//

import Foundation
import StoreKit

struct TrackingParameters {
  let delegateParams: [String: Any]
  let eventParams: [String: Any]
}

enum InternalEventLogic {
  static func processParameters(
    fromTrackableEvent trackableEvent: Trackable,
    customParameters: [String: Any] = [:]
  ) -> TrackingParameters {
    let superwallParameters = trackableEvent.parameters ?? [:]
    let eventName = trackableEvent.name

    var eventParams: [String: Any] = [:]
    var delegateParams: [String: Any] = [
      "isSuperwall": true
    ]

    // Add a special property if it's an automatically tracked event
    let isStandardEvent = Paywall.EventName(rawValue: eventName) != nil
    eventParams["$is_standard_event"] = isStandardEvent

    // Filter then assign Superwall parameters
    for key in superwallParameters.keys {
      guard let value = clean(input: superwallParameters[key]) else {
        continue
      }

      let keyWithDollar = "$\(key)"
      eventParams[keyWithDollar] = value

      // no $ for delegate methods
      delegateParams[key] = value
    }

    // Filter then assign custom parameters
    for key in customParameters.keys {
      guard let value = clean(input: customParameters[key]) else {
        Logger.debug(
          logLevel: .debug,
          scope: .events,
          message: "Dropping Key",
          info: ["key": key, "name": eventName, "reason": "Failed to serialize value"]
        )
        continue
      }

      if key.starts(with: "$") {
        Logger.debug(
          logLevel: .info,
          scope: .events,
          message: "Dropping Key",
          info: ["key": key, "name": eventName, "reason": "$ signs not allowed"]
        )
      } else {
        delegateParams[key] = value
        eventParams[key] = value
      }
    }

    return TrackingParameters(
      delegateParams: delegateParams,
      eventParams: eventParams
    )
  }

  static func clean(input: Any?) -> Any? {
    if input is NSArray {
      return nil
    } else if input is NSDictionary {
      return nil
    } else {
      if let input = input {
        let json = JSON(input)
        if json.error == nil {
          return input
        } else {
          if let date = input as? Date {
            return date.isoString
          } else if let url = input as? URL {
            return url.absoluteString
          } else {
            return nil
          }
        }
      }
    }

    return nil
  }
}
