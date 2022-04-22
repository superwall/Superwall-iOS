//
//  File.swift
//  
//
//  Created by Jake Mor on 8/16/21.
//

import Foundation
import StoreKit

extension Paywall {
  private static var queue = EventsQueue()

	@discardableResult
  static func track(
    _ trackableEvent: Trackable,
    customParameters: [String: Any] = [:]
  ) -> (data: EventData, parameters: TrackingParameters) {
    // Get parameters to be sent to the delegate and stored in an event.
    let parameters = InternalEventLogic.processParameters(
      fromTrackableEvent: trackableEvent,
      customParameters: customParameters
    )

    // For a trackable superwall event, send params to delegate
    if trackableEvent is TrackableSuperwallEvent {
      Paywall.delegate?.trackAnalyticsEvent?(
        withName: trackableEvent.rawName,
        params: parameters.delegateParams
      )
      Logger.debug(
        logLevel: .debug,
        scope: .events,
        message: "Logged Event",
        info: parameters.eventParams
      )
    }

		let eventData = EventData(
      name: trackableEvent.rawName,
      parameters: JSON(parameters.eventParams),
      createdAt: Date().isoString
    )
		queue.enqueue(event: eventData.jsonData)

    if trackableEvent.canTriggerPaywall {
			Paywall.shared.handleTrigger(forEvent: eventData)
		}

		return (eventData, parameters)
  }

  // MARK: - Deprecated

  @available(*, deprecated)
  enum StandardEventName: String { //  add defs
    case deepLinkOpen = "deepLink_open"
    case onboardingStart = "onboarding_start"
    case onboardingComplete = "onboarding_complete"
    case pushNotificationReceive = "pushNotification_receive"
    case pushNotificationOpen = "pushNotification_open"
    case coreSessionStart = "coreSession_start" // i.e. call this on "workout_started"
    case coreSessionAbandon = "coreSession_abandon" // i.e. call this on "workout_cancelled"
    case coreSessionComplete = "coreSession_complete" // i.e. call this on "workout_complete"
    case signUp = "sign_up"
    case logIn = "log_in"
    case logOut = "log_out"
    case userAttributes = "user_attributes"
    case base = "base"
  }
}
