//
//  File.swift
//  
//
//  Created by Yusuf Tör on 26/09/2022.
//
// swiftlint:disable function_body_length

import UIKit
import Combine

struct PaywallVcPipelineOutput {
  let request: PresentationRequest
  let triggerResult: TriggerResult
  let debugInfo: DebugInfo
  let paywallViewController: PaywallViewController
  let confirmableAssignment: ConfirmableAssignment?
}

extension AnyPublisher where Output == TriggerResultResponsePipelineOutput, Failure == Error {
  /// Requests the paywall view controller to present. If an error occurred during this,
  /// or a paywall is already presented, it cancels the pipeline and sends an `error`
  /// state to the paywall state publisher.
  ///
  /// - Parameters:
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A publisher that contains info for the next pipeline operator.
  func getPaywallViewController(
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) -> AnyPublisher<PaywallVcPipelineOutput, Error> {
    asyncMap { input in
      let responseIdentifiers = ResponseIdentifiers(
        paywallId: input.experiment.variant.paywallId,
        experiment: input.experiment
      )
      let dependencyContainer = input.request.dependencyContainer

      let paywallRequest = dependencyContainer.makePaywallRequest(
        eventData: input.request.presentationInfo.eventData,
        responseIdentifiers: responseIdentifiers,
        overrides: .init(
          products: input.request.paywallOverrides?.products,
          isFreeTrial: input.request.presentationInfo.freeTrialOverride
        )
      )

      do {
        let paywallViewController = try await dependencyContainer.paywallManager.getPaywallViewController(
          from: paywallRequest
        )

        // if there's a paywall being presented, don't do anything
        if input.request.flags.isPaywallPresented {
          Logger.debug(
            logLevel: .error,
            scope: .paywallPresentation,
            message: "Paywall Already Presented",
            info: ["message": "Superwall.shared.isPaywallPresented is true"]
          )
          let error = InternalPresentationLogic.presentationError(
            domain: "SWPresentationError",
            code: 102,
            title: "Paywall Already Presented",
            value: "You can only present one paywall at a time."
          )
          Task.detached(priority: .utility) {
            let trackedEvent = InternalSuperwallEvent.UnableToPresent(state: .alreadyPresented)
            await Superwall.shared.track(trackedEvent)
          }
          let state: PaywallState = .skipped(.error(error))
          paywallStatePublisher.send(state)
          paywallStatePublisher.send(completion: .finished)
          throw PresentationPipelineError.cancelled
        }

        let output = PaywallVcPipelineOutput(
          request: input.request,
          triggerResult: input.triggerResult,
          debugInfo: input.debugInfo,
          paywallViewController: paywallViewController,
          confirmableAssignment: input.confirmableAssignment
        )
        return output
      } catch {
        let subscriptionStatus = await input.request.flags.subscriptionStatus.async()
        if InternalPresentationLogic.userSubscribedAndNotOverridden(
          isUserSubscribed: subscriptionStatus == .active,
          overrides: .init(
            isDebuggerLaunched: input.request.flags.isDebuggerLaunched,
            shouldIgnoreSubscriptionStatus: input.request.paywallOverrides?.ignoreSubscriptionStatus
          )
        ) {
          Task.detached(priority: .utility) {
            let trackedEvent = InternalSuperwallEvent.UnableToPresent(state: .userIsSubscribed)
            await Superwall.shared.track(trackedEvent)
          }
          let state: PaywallState = .skipped(.userIsSubscribed)
          paywallStatePublisher.send(state)
          paywallStatePublisher.send(completion: .finished)
          throw PresentationPipelineError.cancelled
        }

        Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "Error Getting Paywall View Controller",
          info: input.debugInfo,
          error: error
        )
        Task.detached(priority: .utility) {
          let trackedEvent = InternalSuperwallEvent.UnableToPresent(state: .noPaywallViewController)
          await Superwall.shared.track(trackedEvent)
        }
        paywallStatePublisher.send(.skipped(.error(error)))
        paywallStatePublisher.send(completion: .finished)
        throw PresentationPipelineError.cancelled
      }
    }
    .eraseToAnyPublisher()
  }
}
