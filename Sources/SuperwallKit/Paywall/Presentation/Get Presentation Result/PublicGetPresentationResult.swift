//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/03/2023.
//

import Foundation

typealias PresentationPipelineError = PaywallPresentationRequestStatusReason

extension Superwall {
  /// Preemptively gets the result of registering a placement.
  ///
  /// This helps you determine whether a particular placement will present a paywall
  /// in the future.
  ///
  /// Note that this method does not present a paywall. To do that, use
  /// ``register(placement:params:handler:feature:)``.
  ///
  /// - Parameters:
  ///    - placement: The name of the placement you want to register.
  ///    - params: Optional parameters you'd like to pass with your placement.
  ///
  /// - Returns: A ``PresentationResult`` that indicates the result of registering an event.
  public func getPresentationResult(
    forPlacement placement: String,
    params: [String: Any]? = nil
  ) async -> PresentationResult {
    let placement = UserInitiatedPlacement.Track(
      rawName: placement,
      canImplicitlyTriggerPaywall: false,
      audienceFilterParams: params ?? [:],
      isFeatureGatable: false
    )

    return await internallyGetPresentationResult(
      forPlacement: placement,
      requestType: .getPresentationResult
    )
  }

  /// Preemptively gets the result of registering an event.
  ///
  /// This helps you determine whether a particular event will present a paywall
  /// in the future.
  ///
  /// Note that this method does not present a paywall. To do that, use
  /// ``register(event:params:handler:feature:)``.
  ///
  /// - Parameters:
  ///     - event: The name of the event you want to register.
  ///     - params: Optional parameters you'd like to pass with your event.
  ///     - completion: A completion block that accepts a ``PresentationResult`` indicating
  ///     the result of tracking an event.
  public func getPresentationResult(
    forEvent event: String,
    params: [String: Any]? = nil,
    completion: @escaping (PresentationResult) -> Void
  ) {
    Task {
      let result = await getPresentationResult(forEvent: event, params: params)
      completion(result)
    }
  }

  /// Called when you need to get the presentation result from an event, whether implicitly or explicitly.
  ///
  /// - Parameters:
  ///   - event: The event that's being tracked.
  ///   - requestType: The presentation request type, which will control the flow of the pipeline.
  func internallyGetPresentationResult(
    forPlacement placement: Trackable,
    requestType: PresentationRequestType
  ) async -> PresentationResult {
    let eventCreatedAt = Date()

    let parameters = await TrackingLogic.processParameters(
      fromTrackablePlacement: placement,
      appSessionId: dependencyContainer.appSessionManager.appSession.id
    )

    let eventData = PlacementData(
      name: placement.rawName,
      parameters: JSON(parameters.audienceFilterParams),
      createdAt: eventCreatedAt
    )

    let presentationRequest = dependencyContainer.makePresentationRequest(
      .explicitTrigger(eventData),
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: requestType
    )

    return await getPresentationResult(for: presentationRequest)
  }

  /// Objective-C-only function to preemptively gets the result of registering an event.
  ///
  /// This helps you determine whether a particular event will present a paywall
  /// in the future.
  ///
  /// Note that this method does not present a paywall. To do that, use
  /// ``register(event:params:handler:feature:)``.
  ///
  /// - Parameters:
  ///     - event: The name of the event you want to register.
  ///     - params: Optional parameters you'd like to pass with your event.
  ///
  /// - Returns: A ``PresentationResultObjc`` object that contains information about the result of tracking an event.
  @available(swift, obsoleted: 1.0)
  @objc public func getPresentationResult(
    forEvent event: String,
    params: [String: Any]? = nil
  ) async -> PresentationResultObjc {
    let result = await getPresentationResult(forEvent: event, params: params)
    return PresentationResultObjc(trackResult: result)
  }

  /// Objective-C-only function to preemptively gets the result of registering an event.
  ///
  /// This helps you determine whether a particular event will present a paywall
  /// in the future.
  ///
  /// Note that this method does not present a paywall. To do that, use
  /// ``register(event:params:handler:feature:)``.
  ///
  /// - Parameters event: The name of the event you want to register.
  /// - Returns: A ``PresentationResultObjc`` object that contains information about the result of tracking an event.
  @available(swift, obsoleted: 1.0)
  @objc public func getPresentationResult(
    forEvent event: String
  ) async -> PresentationResultObjc {
    let result = await getPresentationResult(forEvent: event, params: nil)
    return PresentationResultObjc(trackResult: result)
  }
}
