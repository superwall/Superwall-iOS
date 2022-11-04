//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/04/2022.
//

import Foundation
import StoreKit


/*
 Delegate params contains:
 1. App Session ID
 2. All cleaned superwall params (non nil)
 3. Cleaned Custom params that don't contain $ signs
 */

/*
 Event params contain:
 1. App Session ID
 2. is_standard_event if it's a superwall event
 3. event_name
 4. superwall params with exra dollar signs attached
 5. custom params that don't contain $ signs
 6. event name
 */

/*
 struct Event {
  let event: SuperwallEvent
  let appSessionId: String
 }



 */

enum TrackingLogic {
  static func processParameters(
    fromTrackableEvent trackableEvent: Trackable,
    eventCreatedAt: Date,
    storage: Storage = Storage.shared
  ) async -> TrackingParameters {
    var superwallParameters = await trackableEvent.getSuperwallParameters()
    superwallParameters["app_session_id"] = AppSessionManager.shared.appSession.id

    let customParameters = trackableEvent.customParameters
    let eventName = trackableEvent.rawName

    var delegateParams: [String: Any] = [
      "is_superwall": true
    ]

    // Add a special property if it's a superwall event
    var isStandardEvent = false
    if trackableEvent is TrackableSuperwallEvent {
      isStandardEvent = true
    }
    var eventParams: [String: Any] = [
      "$is_standard_event": isStandardEvent,
      "$event_name": eventName
    ]

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

  /// Makes optional variables non-optional. Removes `nil`, `NSArray`, `NSDictionary`, and anything that can't be `JSON`, `Date` or `URL`.
  private static func clean(input: Any?) -> Any? {
    guard let input = input else {
      return nil
    }
    if input is NSArray {
      return nil
    } else if input is NSDictionary {
      return nil
    } else {
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
}
