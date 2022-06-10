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

  /// Tracks an analytical event by sending it to the server and, for internal Superwall events, the delegate.
  ///
  /// - Parameters:
  ///   - trackableEvent: The event you want to track.
  ///   - customParameters: Any extra non-Superwall parameters that you want to track.
	@discardableResult
  static func track(_ event: Trackable) -> TrackingResult {
    // Get parameters to be sent to the delegate and stored in an event.
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event
    )

    // For a trackable superwall event, send params to delegate
    if event is TrackableSuperwallEvent {
      Paywall.delegate?.trackAnalyticsEvent?(
        withName: event.rawName,
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
      name: event.rawName,
      parameters: JSON(parameters.eventParams),
      createdAt: Date()
    )
		queue.enqueue(event: eventData.jsonData)
    
    Storage.shared.saveTriggeredEvent(eventData)

    if event.canImplicitlyTriggerPaywall {
			Paywall.shared.handleImplicitTrigger(forEvent: eventData)
		}

    let result = TrackingResult(
      data: eventData,
      parameters: parameters
    )
		return result
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
