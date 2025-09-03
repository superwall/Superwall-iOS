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
    case dontTriggerPaywall
    case closePaywallThenTriggerPaywall
  }

  static func processParameters(
    fromTrackableEvent trackablePlacement: Trackable,
    appSessionId: String
  ) async -> TrackingParameters {
    var superwallParameters = await trackablePlacement.getSuperwallParameters()
    superwallParameters["app_session_id"] = appSessionId

    let uncleanPlacementAudienceFilterParams = trackablePlacement.audienceFilterParams
    let placementName = trackablePlacement.rawName

    // Pre-calculate expected capacity to avoid expensive dictionary resizing
    let expectedSize = superwallParameters.count + uncleanPlacementAudienceFilterParams.count + 5

    var delegateParams: [String: Any] = [
      "is_superwall": true
    ]
    delegateParams.reserveCapacity(expectedSize)

    // Add a special property if it's a superwall placement
    let isSuperwallEvent = trackablePlacement is TrackableSuperwallEvent

    var audienceFilterParams: [String: Any] = [
      "$is_standard_event": isSuperwallEvent,
      "$event_name": placementName,
      "event_name": placementName
    ]
    // Reserve extra capacity since this dictionary gets both original and $-prefixed keys
    audienceFilterParams.reserveCapacity(expectedSize * 2)

    // Filter then assign Superwall parameters
    for key in superwallParameters.keys {
      guard let value = clean(input: superwallParameters[key]) else {
        continue
      }

      let keyWithDollar = "$\(key)"
      audienceFilterParams[keyWithDollar] = value

      // no $ for delegate methods
      delegateParams[key] = value
    }

    // Filter then assign custom parameters
    for key in uncleanPlacementAudienceFilterParams.keys {
      guard let value = clean(input: uncleanPlacementAudienceFilterParams[key]) else {
        Logger.debug(
          logLevel: .debug,
          scope: .placements,
          message: "Dropping Key",
          info: ["key": key, "name": placementName, "reason": "Failed to serialize value"]
        )
        continue
      }

      if key.starts(with: "$") {
        Logger.debug(
          logLevel: .info,
          scope: .placements,
          message: "Dropping Key",
          info: ["key": key, "name": placementName, "reason": "$ signs not allowed"]
        )
      } else {
        delegateParams[key] = value
        audienceFilterParams[key] = value
      }
    }

    return TrackingParameters(
      delegateParams: delegateParams,
      audienceFilterParams: audienceFilterParams
    )
  }

  static func isNotDisabledVerbosePlacement(
    _ placement: Trackable,
    disableVerbosePlacements: Bool?,
    isSandbox: Bool
  ) -> Bool {
    guard let disableVerbosePlacements = disableVerbosePlacements else {
      return true
    }
    if isSandbox {
      return true
    }

    if placement is InternalSuperwallEvent.PresentationRequest {
      return !disableVerbosePlacements
    }

    if let placement = placement as? InternalSuperwallEvent.PaywallLoad {
      switch placement.state {
      case .start, .complete:
        return !disableVerbosePlacements
      default:
        return true
      }
    }

    if placement is InternalSuperwallEvent.ShimmerLoad {
      return !disableVerbosePlacements
    }

    if let placement = placement as? InternalSuperwallEvent.PaywallProductsLoad {
      switch placement.state {
      case .start, .complete:
        return !disableVerbosePlacements
      default:
        return true
      }
    }

    if let placement = placement as? InternalSuperwallEvent.PaywallWebviewLoad {
      switch placement.state {
      case .start, .complete:
        return !disableVerbosePlacements
      default:
        return true
      }
    }

    return true
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

  /// Checks whether the user is registering a placement with the same name as a superwall event.
  static func checkNotSuperwallEvent(_ event: String) throws {
    for superwallEvent in SuperwallEventObjc.allCases
    where superwallEvent.description == event {
      Logger.debug(
        logLevel: .error,
        scope: .paywallPresentation,
        message: "Do not register a placement with the same name as a SuperwallEvent",
        info: ["event": event]
      )
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "",
          value: "Do not register a placement with the same name as a SuperwallEvent",
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
    paywallViewController: PaywallViewController?
  ) async -> ImplicitTriggerOutcome {
    if let event = event as? TrackableSuperwallEvent,
      case .deepLink = event.superwallEvent {
      return .deepLinkTrigger
    }

    guard triggers.contains(event.rawName) else {
      return .dontTriggerPaywall
    }

    // referring placements in this set are not able to trigger another
    // another paywall. prevents loops from occurring
    let notAllowedReferringPlacementNames: Set<String> = [
      SuperwallEventObjc.transactionAbandon.description,
      SuperwallEventObjc.transactionFail.description,
      SuperwallEventObjc.paywallDecline.description,
      SuperwallEventObjc.customPlacement.description
    ]

    if let referringPlacementName = await paywallViewController?.info.presentedByPlacementWithName,
      notAllowedReferringPlacementNames.contains(referringPlacementName) {
      return .dontTriggerPaywall
    }

    if let placement = event as? TrackableSuperwallEvent {
      switch placement.superwallEvent {
      case .transactionAbandon,
        .transactionFail,
        .paywallDecline,
        .customPlacement,
        .surveyResponse:
        // Make sure the result of presenting will be a paywall, otherwise do not proceed.
        // This is important to stop the paywall from being skipped and firing the feature
        // block when it shouldn't. This has to be done only to those triggers that reassign
        // the statePublisher. Others like app_launch are fine to skip and users are relying
        // on paywallPresentationRequest for those.
        // Also, we need this with surveyResponse because after a purchase it needs to know whether
        // to show a paywall or not.
        let presentationResult = await Superwall.shared.internallyGetPresentationResult(
          forPlacement: placement,
          requestType: .handleImplicitTrigger
        )
        guard case .paywall = presentationResult else {
          return .dontTriggerPaywall
        }
        return .closePaywallThenTriggerPaywall
      default:
        break
      }
    }

    if paywallViewController != nil {
      return .dontTriggerPaywall
    }

    return .triggerPaywall
  }
}
