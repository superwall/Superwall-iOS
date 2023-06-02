//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//
// swiftlint:disable line_length 

import Foundation
import Combine

extension Superwall {
  /// Waits for config to be received and the identity and subscription status of the user to
  /// be established before continuing.
  ///
  /// - Parameters:
  ///   - request: The presentation request.
  ///   - dependencyContainer: Used for testing only.
  func waitToPresent(
    _ request: PresentationRequest,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>? = nil,
    dependencyContainer: DependencyContainer? = nil
  ) async throws {
    let dependencyContainer = dependencyContainer ?? self.dependencyContainer

    // Wait for subscription status, throwing an error on timeout.
    let timer = activateTimerForSubscriptionStatus(
      request: request,
      paywallStatePublisher: paywallStatePublisher,
      dependencyContainer: dependencyContainer
    )

    let subscriptionStatus = await request.flags.subscriptionStatus
      .filter { $0 != .unknown }
      .async()

    if let timer = timer {
      if timer.isValid {
      timer.invalidate()
      } else {
        // Timer has fired, cancel pipeline.
        throw PresentationPipelineError.subscriptionStatusTimeout
      }
    }

    if subscriptionStatus == .active {
      if dependencyContainer.configManager.configSubject.value == nil {
        // If the user is subscribed and there's no config (for whatever reason),
        // just call the feature block.
        throw userIsSubscribed(paywallStatePublisher: paywallStatePublisher)
      } else {
        // If the user is subscribed and there is config, continue.
      }
    } else {
      do {
        // If the user isn't subscribed, wait for config to return.
        try await dependencyContainer.configManager.configSubject
          .throwableHasValue()
      } catch {
        // If config completely dies, then throw an error
        let error = InternalPresentationLogic.presentationError(
          domain: "SWKPresentationError",
          code: 104,
          title: "No Config",
          value: "Trying to present paywall without the Superwall config."
        )
        let state: PaywallState = .presentationError(error)
        paywallStatePublisher?.send(state)
        paywallStatePublisher?.send(completion: .finished)
        throw PresentationPipelineError.noConfig
      }
    }

    // Get the identity. This may or may not wait depending on whether the dev
    // specifically wants to wait for assignments.
    await dependencyContainer.identityManager.hasIdentity.async()
  }

  /// Creates a 5 sec timer. If the subscription status is retrieved, it'll get cancelled. Otherwise will log a
  /// timeout and fail the request.
  private func activateTimerForSubscriptionStatus(
    request: PresentationRequest,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>?,
    dependencyContainer: DependencyContainer
  ) -> Timer? {
    // Don't need to do this when implicit presentation result because the
    // status will already have been retrieved by this point and we don't want to track anything.
    guard request.flags.type != .getImplicitPresentationResult else {
      return nil
    }
    let timer = Timer(
      timeInterval: 5,
      repeats: false
    ) { _ in
      Task { [weak self] in
        guard let self = self else {
          return
        }
        Task {
          let trackedEvent = InternalSuperwallEvent.PresentationRequest(
            eventData: request.presentationInfo.eventData,
            type: request.flags.type,
            status: .timeout,
            statusReason: .subscriptionStatusTimeout
          )
          await self.track(trackedEvent)
        }
        Logger.debug(
          logLevel: .info,
          scope: .paywallPresentation,
          message: "Timeout: Superwall.shared.subscriptionStatus has been \"unknown\" for over 5 seconds resulting in a failure."
        )
        let error = InternalPresentationLogic.presentationError(
          domain: "SWKPresentationError",
          code: 105,
          title: "Timeout",
          value: "The subscription status failed to change from \"unknown\"."
        )
        paywallStatePublisher?.send(.presentationError(error))
        paywallStatePublisher?.send(completion: .finished)
      }
    }
    RunLoop.main.add(timer, forMode: .default)
    return timer
  }
}
