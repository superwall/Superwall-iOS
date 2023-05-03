//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//
// swiftlint:disable line_length

import Foundation
import Combine

extension AnyPublisher where Output == PresentationRequest, Failure == Error {
  /// Waits for config to be received and the identity and subscription status of the user to
  /// be established.
  func waitToPresent() -> AnyPublisher<PresentationRequest, Failure> {
    subscribe(on: DispatchQueue.global(qos: .userInitiated))
      .flatMap { _ in
        return startTimer()
      }
      .flatMap { request, timer in
        zip(
          request.dependencyContainer.identityManager.hasIdentity,
          request.dependencyContainer.configManager.hasConfig,
          request.flags.subscriptionStatus
            .filter { $0 != .unknown }
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
        )
        .map { (request, timer, $0.0, $0.1, $0.2) }
      }
      .first()
      .map { request, timer, _, _, _ in
        timer.invalidate()
        return request
      }
      .eraseToAnyPublisher()
  }

  private func startTimer() -> (AnyPublisher<(PresentationRequest, Timer), Failure>) {
    map { request in
      let timer = Timer(
        timeInterval: 5,
        repeats: false
      ) { [request] _ in
        Task.detached {
          let trackedEvent = InternalSuperwallEvent.PresentationRequest(
            eventData: request.presentationInfo.eventData,
            type: request.flags.type,
            status: .timeout,
            statusReason: nil
          )
          await Superwall.shared.track(trackedEvent)

          var timeoutReason = ""
          let subscriptionStatus = await request.flags.subscriptionStatus.async()
          if subscriptionStatus == .unknown {
            timeoutReason += "\nSuperwall.shared.subscriptionStatus is currently \"unknown\". A paywall cannot show in this state."
          }
          if request.dependencyContainer.configManager.config == nil {
            timeoutReason += "\nThe config for the user has not returned from the server."
          }

          let hasIdentity = await request.dependencyContainer.identityManager.hasIdentity.async()
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
      RunLoop.main.add(timer, forMode: .default)

      return (request, timer)
    }
    .eraseToAnyPublisher()
  }
}
