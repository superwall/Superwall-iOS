//
//  File.swift
//  
//
//  Created by Jake Mor on 8/16/21.
//

import Foundation
import StoreKit

extension Superwall {
  private static var queue = EventsQueue()

  /// Tracks an analytical event by sending it to the server and, for internal Superwall events, the delegate.
  ///
  /// - Parameters:
  ///   - trackableEvent: The event you want to track.
  ///   - customParameters: Any extra non-Superwall parameters that you want to track.
	@discardableResult
  static func track(_ event: Trackable) async -> TrackingResult {
    // Get parameters to be sent to the delegate and stored in an event.
    let eventCreatedAt = Date()
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      eventCreatedAt: eventCreatedAt
    )

    // For a trackable superwall event, send params to delegate
    if let trackedEvent = event as? TrackableSuperwallEvent {
      let info = SuperwallEventInfo(
        event: trackedEvent.superwallEvent,
        params: parameters.delegateParams
      )

      await shared.delegateAdapter.didTrackSuperwallEvent(info)

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
		await queue.enqueue(event: eventData.jsonData)
    Storage.shared.coreDataManager.saveEventData(eventData)

    if event.canImplicitlyTriggerPaywall {
      Task.detached {
        await shared.handleImplicitTrigger(
          forEvent: event,
          withData: eventData
        )
      }
		}

    let result = TrackingResult(
      data: eventData,
      parameters: parameters
    )
		return result
  }

  /// Attemps to implicitly trigger a paywall for a given analytical event.
  ///
  ///  - Parameters:
  ///     - event: The tracked event.
  ///     - eventData: The event data that could trigger a paywall.
  @MainActor
  func handleImplicitTrigger(
    forEvent event: Trackable,
    withData eventData: EventData
  ) async {
    await IdentityManager.hasIdentity.async()

    let presentationInfo: PresentationInfo = .implicitTrigger(eventData)

    let outcome = TrackingLogic.canTriggerPaywall(
      event,
      triggers: Set(configManager.triggersByEventName.keys),
      isPaywallPresented: isPaywallPresented
    )

    switch outcome {
    case .deepLinkTrigger:
      if isPaywallPresented {
        await Superwall.dismiss()
      }
      let presentationRequest = PresentationRequest(
        presentationInfo: presentationInfo,
        injections: .init(
          isDebuggerLaunched: SWDebugManager.shared.isDebuggerLaunched,
          isUserSubscribed: isUserSubscribed
        )
      )
      await internallyPresent(presentationRequest).asyncNoValue()
    case .triggerPaywall:
      // delay in case they are presenting a view controller alongside an event they are calling
      let twoHundredMilliseconds = UInt64(200_000_000)
      try? await Task.sleep(nanoseconds: twoHundredMilliseconds)
      let presentationRequest = PresentationRequest(
        presentationInfo: presentationInfo,
        injections: .init(
          isDebuggerLaunched: SWDebugManager.shared.isDebuggerLaunched,
          isUserSubscribed: isUserSubscribed
        )
      )
      await internallyPresent(presentationRequest).asyncNoValue()
    case .disallowedEventAsTrigger:
      Logger.debug(
        logLevel: .warn,
        scope: .superwallCore,
        message: "Event Used as Trigger",
        info: ["message": "You can't use events as triggers"],
        error: nil
      )
    case .dontTriggerPaywall:
      return
    }
  }
}
