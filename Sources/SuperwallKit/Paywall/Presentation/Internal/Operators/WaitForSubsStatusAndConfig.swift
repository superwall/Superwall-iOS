//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//
// swiftlint:disable function_body_length

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

    let configState = dependencyContainer.configManager.configState

    // First try to get config. If no config, wait for it.
    if configState.value.getConfig() == nil {
      do {
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
    } else {
      // If there is config, continue.
    }

    // Now get the subscription status. This has to be done after the retrieving
    // of config because entitlements are within config. Otherwise, if config
    // hasn't been retrieved we would get an error saying "subscriptionStatus not set"
    // but actually it's a config issue.
    let subscriptionStatusTask = Task {
      return try await request.flags.subscriptionStatus
        .filter { $0 != .unknown }
        .throwableAsync()
    }

    // Capture only the cancel action because the whole task is non-sendable and gives a warning.
    let cancelTask = {
      subscriptionStatusTask.cancel()
    }

    // Create a 5 sec timer. If the subscription status is retrieved it'll
    // get cancelled. Otherwise will log a timeout and fail the request.
    let timer = Timer(
      timeInterval: 5,
      repeats: false
    ) { _ in
      cancelTask()
    }
    RunLoop.main.add(timer, forMode: .default)

    do {
      _ = try await subscriptionStatusTask.value
    } catch {
      Task {
        let presentationRequest = InternalSuperwallEvent.PresentationRequest(
          placementData: request.presentationInfo.placementData,
          type: request.flags.type,
          status: .timeout,
          statusReason: .subscriptionStatusTimeout,
          factory: dependencyContainer
        )
        await self.track(presentationRequest)
      }
      Logger.debug(
        logLevel: .info,
        scope: .paywallPresentation,
        message: "Timeout: Superwall.shared.subscriptionStatus has not been set "
        + "for over 5 seconds resulting in a failure."
      )
      let error = InternalPresentationLogic.presentationError(
        domain: "SWKPresentationError",
        code: 105,
        title: "Timeout",
        value: "The subscription status was not set."
      )
      paywallStatePublisher?.send(.presentationError(error))
      paywallStatePublisher?.send(completion: .finished)
      throw PresentationPipelineError.subscriptionStatusTimeout
    }

    timer.invalidate()

    // Get the identity. This may or may not wait depending on whether the dev
    // specifically wants to wait for assignments.
    try await dependencyContainer.identityManager.hasIdentity.throwableAsync()
  }
}
