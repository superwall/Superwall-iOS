//
//  File.swift
//  
//
//  Created by Yusuf Tör on 26/09/2022.

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
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>? = nil
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
          from: paywallRequest,
          isPreloading: false,
          isDebuggerLaunched: input.request.flags.isDebuggerLaunched,
          delegate: input.request.flags.type.getPaywallVcDelegateAdapter()
        )

        let output = PaywallVcPipelineOutput(
          request: input.request,
          triggerResult: input.triggerResult,
          debugInfo: input.debugInfo,
          paywallViewController: paywallViewController,
          confirmableAssignment: input.confirmableAssignment
        )
        return output
      } catch {
        switch input.request.flags.type {
        case .getImplicitPresentationResult,
          .getPresentationResult:
          throw GetPresentationResultError.paywallNotAvailable
        case .presentation,
          .getPaywallViewController:
          guard let paywallStatePublisher = paywallStatePublisher else {
            // Will never get here
            throw error
          }
          throw await presentationFailure(error, input, paywallStatePublisher)
        }
      }
    }
    .eraseToAnyPublisher()
  }

  private func presentationFailure(
    _ error: Error,
    _ input: TriggerResultResponsePipelineOutput,
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) async -> Error {
    let subscriptionStatus = await input.request.flags.subscriptionStatus.async()
    if InternalPresentationLogic.userSubscribedAndNotOverridden(
      isUserSubscribed: subscriptionStatus == .active,
      overrides: .init(
        isDebuggerLaunched: input.request.flags.isDebuggerLaunched,
        shouldIgnoreSubscriptionStatus: input.request.paywallOverrides?.ignoreSubscriptionStatus
      )
    ) {
      let state: PaywallState = .skipped(.userIsSubscribed)
      paywallStatePublisher.send(state)
      paywallStatePublisher.send(completion: .finished)
      return PresentationPipelineError.userIsSubscribed
    }

    Logger.debug(
      logLevel: .error,
      scope: .paywallPresentation,
      message: "Error Getting Paywall View Controller",
      info: input.debugInfo,
      error: error
    )
    paywallStatePublisher.send(.presentationError(error))
    paywallStatePublisher.send(completion: .finished)
    return PresentationPipelineError.noPaywallViewController
  }
}
