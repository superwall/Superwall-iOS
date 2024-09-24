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
  /// Waits for config to be received and the identity and entitlements of the user to
  /// be established before continuing.
  ///
  /// - Parameters:
  ///   - request: The presentation request.
  ///   - dependencyContainer: Used for testing only.
  func waitForEntitlementsAndConfig(
    _ request: PresentationRequest,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>? = nil,
    dependencyContainer: DependencyContainer? = nil
  ) async throws {
    let dependencyContainer = dependencyContainer ?? self.dependencyContainer

    let isEntitlementsReadyTask = Task {
      for try await value in request.flags.entitlements.$didSetActiveEntitlements.values where value == true {
        return
      }
      throw CancellationError()
    }

    // Create a 5 sec timer. If the entitlements are retrieved it'll
    // get cancelled. Otherwise will log a timeout and fail the request.
    let timer = Timer(
      timeInterval: 5,
      repeats: false
    ) { _ in
      isEntitlementsReadyTask.cancel()
    }
    RunLoop.main.add(timer, forMode: .default)

    do {
      try await isEntitlementsReadyTask.value
    } catch {
      Task {
        let presentationRequest = InternalSuperwallPlacement.PresentationRequest(
          placementData: request.presentationInfo.placementData,
          type: request.flags.type,
          status: .timeout,
          statusReason: .entitlementsTimeout,
          factory: dependencyContainer
        )
        await self.track(presentationRequest)
      }
      Logger.debug(
        logLevel: .info,
        scope: .paywallPresentation,
        message: "Timeout: Superwall.shared.entitlements have not been set for over 5 seconds resulting in a failure."
      )
      let error = InternalPresentationLogic.presentationError(
        domain: "SWKPresentationError",
        code: 105,
        title: "Timeout",
        value: "The entitlements were not set."
      )
      paywallStatePublisher?.send(.presentationError(error))
      paywallStatePublisher?.send(completion: .finished)
      throw PresentationPipelineError.entitlementsTimeout
    }

    timer.invalidate()

    let configState = dependencyContainer.configManager.configState

    if request.flags.entitlements.active.isEmpty {
      do {
        // If the user has no active entitlements, wait for config to return.
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
                let presentationRequest = InternalSuperwallPlacement.PresentationRequest(
                  placementData: request.presentationInfo.placementData,
                  type: request.flags.type,
                  status: .timeout,
                  statusReason: .noConfig,
                  factory: dependencyContainer
                )
                await self.track(presentationRequest)
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
    }

    // Get the identity. This may or may not wait depending on whether the dev
    // specifically wants to wait for assignments.
    try await dependencyContainer.identityManager.hasIdentity.throwableAsync()
  }
}
