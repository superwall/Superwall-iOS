//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/04/2022.
//

import Foundation
import StoreKit

enum TrackingLogic {
  enum ImplicitTriggerOutcome {
    case triggerPaywall
    case deepLinkTrigger
    case disallowedEventAsTrigger
    case dontTriggerPaywall
  }

  static func processParameters(
    fromTrackableEvent trackableEvent: Trackable,
    eventCreatedAt: Date,
    appSessionId: String
  ) async -> TrackingParameters {
    var superwallParameters = await trackableEvent.getSuperwallParameters()
    superwallParameters["app_session_id"] = appSessionId

    let customParameters = trackableEvent.customParameters
    let eventName = trackableEvent.rawName

    var delegateParams: [String: Any] = [
      "is_superwall": true
    ]

    // Add a special property if it's a superwall event
    let isStandardEvent = trackableEvent is TrackableSuperwallEvent

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

  /// Checks whether the user is tracking an event with the same name as a superwall event.
  static func checkNotSuperwallEvent(_ event: String) throws {
    for superwallEvent in SuperwallEventObjc.allCases where superwallEvent.description == event {
      Logger.debug(
        logLevel: .error,
        scope: .paywallPresentation,
        message: "Do not track an event with the same name as a SuperwallEvent",
        info: ["event": event]
      )
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "",
          value: "Do not track an event with the same name as a SuperwallEvent",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "com.superwall",
        code: 400,
        userInfo: userInfo
      )
      throw error
    }
  }

  static func canTriggerPaywall(
    _ event: Trackable,
    triggers: Set<String>,
    isPaywallPresented: Bool
  ) -> ImplicitTriggerOutcome {
    if let event = event as? TrackableSuperwallEvent,
      case .deepLink(url: _) = event.superwallEvent {
      return .deepLinkTrigger
    }

    if isPaywallPresented {
      return .dontTriggerPaywall
    }
    guard triggers.contains(event.rawName) else {
      return .dontTriggerPaywall
    }

    return .triggerPaywall
  }
}
