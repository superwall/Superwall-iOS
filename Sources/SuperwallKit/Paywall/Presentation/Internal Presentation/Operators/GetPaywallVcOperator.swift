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
  enum PipelineType {
    case getPresentationResult
    case presentation(PassthroughSubject<PaywallState, Never>)
  }
  /// Requests the paywall view controller to present. If an error occurred during this,
  /// or a paywall is already presented, it cancels the pipeline and sends an `error`
  /// state to the paywall state publisher.
  ///
  /// - Parameters:
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A publisher that contains info for the next pipeline operator.
  func getPaywallViewController(pipelineType: PipelineType) -> AnyPublisher<PaywallVcPipelineOutput, Error> {
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
          isDebuggerLaunched: input.request.flags.isDebuggerLaunched
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
        switch pipelineType {
        case .getPresentationResult:
          throw GetPresentationResultError.paywallNotAvailable
        case .presentation(let paywallStatePublisher):
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
    Task.detached(priority: .utility) {
      let trackedEvent = InternalSuperwallEvent.UnableToPresent(state: .noPaywallViewController)
      await Superwall.shared.track(trackedEvent)
    }
    paywallStatePublisher.send(.presentationError(error))
    paywallStatePublisher.send(completion: .finished)
    return PresentationPipelineError.noPaywallViewController
  }
}
