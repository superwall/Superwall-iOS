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
    let eventCreatedAt = Date()
    let parameters = TrackingLogic.processParameters(
      fromTrackableEvent: event,
      eventCreatedAt: eventCreatedAt
    )

    // For a trackable superwall event, send params to delegate
    if event is TrackableSuperwallEvent {
      delegate?.trackAnalyticsEvent?(
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
      createdAt: eventCreatedAt
    )
		queue.enqueue(event: eventData.jsonData)
    Storage.shared.coreDataManager.saveEventData(eventData)

    if event.canImplicitlyTriggerPaywall {
			shared.handleImplicitTrigger(forEvent: eventData)
		}

    let result = TrackingResult(
      data: eventData,
      parameters: parameters
    )
		return result
  }
}
