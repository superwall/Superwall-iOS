//
//  File.swift
//  
//
//  Created by Jake Mor on 8/16/21.
//

import Foundation
import StoreKit

extension Superwall {
  /// Tracks an analytical event by sending it to the server and, for internal Superwall events, the delegate.
  ///
  /// - Parameters:
  ///   - trackableEvent: The event you want to track.
  ///   - customParameters: Any extra non-Superwall parameters that you want to track.
	@discardableResult
  func track(_ event: Trackable) async -> TrackingResult {
    // Get parameters to be sent to the delegate and stored in an event.
    let eventCreatedAt = Date()
    let parameters = await TrackingLogic.processParameters(
      fromTrackableEvent: event,
      eventCreatedAt: eventCreatedAt,
      appSessionId: dependencyContainer.appSessionManager.appSession.id
    )

    // For a trackable superwall event, send params to delegate
    if let trackedEvent = event as? TrackableSuperwallEvent {
      let info = SuperwallEventInfo(
        event: trackedEvent.superwallEvent,
        params: parameters.delegateParams
      )

      await dependencyContainer.delegateAdapter.didTrackSuperwallEventInfo(info)

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
    await dependencyContainer.queue.enqueue(event: eventData.jsonData)
    dependencyContainer.storage.coreDataManager.saveEventData(eventData)

    if event.canImplicitlyTriggerPaywall {
      Task.detached { [weak self] in
        await self?.handleImplicitTrigger(
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
    await dependencyContainer.identityManager.hasIdentity.async()

    let presentationInfo: PresentationInfo = .implicitTrigger(eventData)

    let outcome = TrackingLogic.canTriggerPaywall(
      event,
      triggers: Set(dependencyContainer.configManager.triggersByEventName.keys),
      isPaywallPresented: isPaywallPresented
    )

    switch outcome {
    case .deepLinkTrigger:
      if isPaywallPresented {
        await dismiss()
      }
      let presentationRequest = dependencyContainer.makePresentationRequest(
        presentationInfo,
        isPaywallPresented: isPaywallPresented
      )
      await internallyPresent(presentationRequest).asyncNoValue()
    case .triggerPaywall:
      // delay in case they are presenting a view controller alongside an event they are calling
      let milliseconds = 200
      let nanoseconds = UInt64(milliseconds * 1_000_000)
      try? await Task.sleep(nanoseconds: nanoseconds)
      let presentationRequest = dependencyContainer.makePresentationRequest(
        presentationInfo,
        isPaywallPresented: isPaywallPresented
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
