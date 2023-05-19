//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//
// swiftlint:disable line_length 

import Foundation
import SystemConfiguration
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
    let timer = startTimer(
      for: request,
      dependencyContainer: dependencyContainer
    )

    let task = Task {
      async let hasIdentity = dependencyContainer.identityManager.hasIdentity.throwableAsync()
      async let hasConfig = dependencyContainer.configManager.hasConfig.throwableAsync()
      async let subscriptionStatus = request.flags.subscriptionStatus
        .filter { $0 != .unknown }
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
        .throwableAsync()

      _ = await (try hasIdentity, try hasConfig, try subscriptionStatus)
    }

    if !request.flags.hasInternet {
      task.cancel()
    }

    do {
      try await task.value
    } catch {
      let error = InternalPresentationLogic.presentationError(
        domain: "SWKPresentationError",
        code: 104,
        title: "No Internet",
        value: "Trying to present paywall with no internet."
      )
      let state: PaywallState = .presentationError(error)
      paywallStatePublisher?.send(state)
      paywallStatePublisher?.send(completion: .finished)
      throw PresentationPipelineError.noInternet
    }

    timer?.invalidate()
  }

  /// Starts a 5 sec timer. If pipeline above progresses, it'll get cancelled. Otherwise will log a
  /// timeout for the user.
  private func startTimer(
    for request: PresentationRequest,
    dependencyContainer: DependencyContainer
  ) -> Timer? {
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
            statusReason: nil
          )
          await self.track(trackedEvent)
        }
        var timeoutReason = ""
        let subscriptionStatus = await request.flags.subscriptionStatus.async()
        if subscriptionStatus == .unknown {
          timeoutReason += "\nSuperwall.shared.subscriptionStatus is currently \"unknown\". A paywall cannot show in this state."
        }
        if self.dependencyContainer.configManager.config == nil {
          timeoutReason += "\nThe config for the user has not returned from the server."
        }

        let hasIdentity = await dependencyContainer.identityManager.hasIdentity.async()
        if !hasIdentity {
          timeoutReason += "\nThe user's identity has not been set."
        }
        Logger.debug(
          logLevel: .info,
          scope: .paywallPresentation,
          message: "Timeout: Waiting for >5 seconds to continue paywall request. Your paywall may not show because:\(timeoutReason)"
        )
      }
    }

    return timer
  }
}
