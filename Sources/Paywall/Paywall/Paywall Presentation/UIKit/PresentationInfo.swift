//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/05/2022.
//

import Foundation

enum PresentationInfo {
  case implicitTrigger(EventData)
  case explicitTrigger(EventData)
  case fromIdentifier(String)
  case defaultPaywall

  var eventData: EventData? {
    switch self {
    case let .implicitTrigger(eventData),
      let .explicitTrigger(eventData):
      return eventData
    default:
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

  // TODO: CHECK THAT THIS IS CORRECT FOR IDENTIFIER/DEFAULT PAYWALL
  var triggerType: TriggerSession.Trigger.TriggerType {
    switch self {
    case .implicitTrigger:
      return .implicit
    default:
      return .explicit
    }
  }
}
