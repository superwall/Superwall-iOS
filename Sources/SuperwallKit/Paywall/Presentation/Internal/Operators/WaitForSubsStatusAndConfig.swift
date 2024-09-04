//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//
// swiftlint:disable line_length function_body_length

import Foundation
import Combine

extension Superwall {
  /// Waits for config to be received and the identity and subscription status of the user to
  /// be established before continuing.
  ///
  /// - Parameters:
  ///   - request: The presentation request.
  ///   - dependencyContainer: Used for testing only.
  func waitForSubsStatusAndConfig(
    _ request: PresentationRequest,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>? = nil,
    dependencyContainer: DependencyContainer? = nil
  ) async throws {
    let dependencyContainer = dependencyContainer ?? self.dependencyContainer

    let subscriptionStatusTask = Task {
      return try await request.flags.subscriptionStatus
        .filter { $0 != .unknown }
        .throwableAsync()
    }

    // Create a 5 sec timer. If the subscription status is retrieved, it'll
    // get cancelled. Otherwise will log a timeout and fail the request.
    let timer = Timer(
      timeInterval: 5,
      repeats: false
    ) { _ in
      subscriptionStatusTask.cancel()
    }
    RunLoop.main.add(timer, forMode: .default)

    let subscriptionStatus: SubscriptionStatus
    do {
      subscriptionStatus = try await subscriptionStatusTask.value
    } catch {
      Task {
        let trackedEvent = InternalSuperwallPlacement.PresentationRequest(
          placementData: request.presentationInfo.eventData,
          type: request.flags.type,
          status: .timeout,
          statusReason: .subscriptionStatusTimeout,
          factory: dependencyContainer
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
      throw PresentationPipelineError.subscriptionStatusTimeout
    }

    timer.invalidate()

    let configState = dependencyContainer.configManager.configState

    if subscriptionStatus == .active {
      if configState.value.getConfig() == nil {
        if configState.value == .retrieving {
          // If config is nil and we're still retrieving, wait for <=1 second.
          // At 1s we cancel the task and check config again.
          let timedTask = Task {
            return try await dependencyContainer.configManager.configState
              .compactMap { $0.getConfig() }
              .throwableAsync()
          }

          let timer = Timer(
            timeInterval: 1,
            repeats: false
          ) { _ in
            timedTask.cancel()
          }
          RunLoop.main.add(timer, forMode: .default)

          do {
            _ = try await timedTask.value
          } catch {
            if configState.value.getConfig() == nil {
              // Still failed to get config, call feature block.
              Task {
                let trackedEvent = InternalSuperwallPlacement.PresentationRequest(
                  placementData: request.presentationInfo.eventData,
                  type: request.flags.type,
                  status: .timeout,
                  statusReason: .noConfig,
                  factory: dependencyContainer
                )
                await self.track(trackedEvent)
              }
              Logger.debug(
                logLevel: .info,
                scope: .paywallPresentation,
                message: "Timeout: The config could not be retrieved in a reasonable time for a subscribed user."
              )
              throw userIsSubscribed(paywallStatePublisher: paywallStatePublisher)
            }
          }

          // Got config, cancel the timer.
          timer.invalidate()
        } else {
          // If the user is subscribed and there's no config (for whatever reason),
          // just call the feature block.
          throw userIsSubscribed(paywallStatePublisher: paywallStatePublisher)
        }
      } else {
        // If the user is subscribed and there is config, continue.
      }
    } else {
      do {
        // If the user isn't subscribed, wait for config to return.
        try await dependencyContainer.configManager.configState
          .compactMap { $0.getConfig() }
          .throwableAsync()
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
    try await dependencyContainer.identityManager.hasIdentity.throwableAsync()
  }
}
