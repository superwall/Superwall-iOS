//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/05/2022.
//

import Foundation

/// Contains information about the presentation of a paywall.
enum PresentationInfo {
  case implicitTrigger(EventData)
  case explicitTrigger(EventData)
  case fromIdentifier(String)

  var eventData: EventData? {
    switch self {
    case let .implicitTrigger(eventData),
      let .explicitTrigger(eventData):
      return eventData
    default:
      return nil
    }
  }

  var eventName: String? {
    switch self {
    case let .implicitTrigger(eventData),
      let .explicitTrigger(eventData):
      return eventData.name
    case .fromIdentifier:
      return nil
    }
  }

  var identifier: String? {
    switch self {
    case .fromIdentifier(let identifier):
      return identifier
    default:
      return nil
    }
  }

  var calledByIdentifier: Bool {
    switch self {
    case .fromIdentifier:
      return true
    default:
      return false
    }
  }

  var triggerType: TriggerSession.Trigger.TriggerType {
    switch self {
    case .implicitTrigger:
      return .implicit
    default:
      return .explicit
    }
  }
}
