//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/05/2022.
//

import Foundation

/// Contains information about the presentation of a paywall.
enum PresentationInfo {
  case implicitTrigger(PlacementData)
  case explicitTrigger(PlacementData)

  /// Only used in the `DebugViewController`
  case fromIdentifier(_ identifier: String, freeTrialOverride: Bool)

  var freeTrialOverride: Bool? {
    switch self {
    case .fromIdentifier(_, let freeTrialOverride):
      return freeTrialOverride
    default:
      return nil
    }
  }

  var eventData: PlacementData? {
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
    case .fromIdentifier(let identifier, _):
      return identifier
    default:
      return nil
    }
  }
}
