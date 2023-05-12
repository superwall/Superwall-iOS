//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation
import Combine

struct PaywallVcPipelineOutput {
  let triggerResult: TriggerResult
  let debugInfo: [String: Any]
  let paywallViewController: PaywallViewController
  let confirmableAssignment: ConfirmableAssignment?
}

extension Superwall {
  /// Requests the paywall view controller to present. If an error occurred during this,
  /// or a paywall is already presented, it cancels the pipeline and sends an `error`
  /// state to the paywall state publisher.
  ///
  /// - Parameters:
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///
  /// - Returns: A publisher that contains info for the next pipeline operator.
  func getPaywallViewController(
    _ request: PresentationRequest,
    _ input: TriggerResultResponsePipelineOutput,
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>? = nil
  ) async throws -> PaywallVcPipelineOutput {
    let responseIdentifiers = ResponseIdentifiers(
      paywallId: input.experiment.variant.paywallId,
      experiment: input.experiment
    )
    let paywallRequest = dependencyContainer.makePaywallRequest(
      eventData: request.presentationInfo.eventData,
      responseIdentifiers: responseIdentifiers,
      overrides: .init(
        products: request.paywallOverrides?.products,
        isFreeTrial: request.presentationInfo.freeTrialOverride
      ),
      isDebuggerLaunched: request.flags.isDebuggerLaunched
    )
    do {
      let paywallViewController = try await dependencyContainer.paywallManager.getPaywallViewController(
        from: paywallRequest,
        isPreloading: false,
        delegate: request.flags.type.getPaywallVcDelegateAdapter()
      )

      let output = PaywallVcPipelineOutput(
        triggerResult: input.triggerResult,
        debugInfo: input.debugInfo,
        paywallViewController: paywallViewController,
        confirmableAssignment: input.confirmableAssignment
      )
      return output
    } catch {
      switch request.flags.type {
      case .getImplicitPresentationResult,
          .getPresentationResult:
        throw PresentationPipelineError.noPaywallViewController
      case .presentation,
          .getPaywallViewController:
        guard let paywallStatePublisher = paywallStatePublisher else {
          // Will never get here
          throw error
        }
        throw await presentationFailure(error, request, input.debugInfo, paywallStatePublisher)
      }
    }
  }

  private func presentationFailure(
    _ error: Error,
    _ request: PresentationRequest,
    _ debugInfo: [String: Any],
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) async -> Error {
    let subscriptionStatus = await request.flags.subscriptionStatus.async()
    if InternalPresentationLogic.userSubscribedAndNotOverridden(
      isUserSubscribed: subscriptionStatus == .active,
      overrides: .init(
        isDebuggerLaunched: request.flags.isDebuggerLaunched,
        shouldIgnoreSubscriptionStatus: request.paywallOverrides?.ignoreSubscriptionStatus
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
      info: debugInfo,
      error: error
    )
    paywallStatePublisher.send(.presentationError(error))
    paywallStatePublisher.send(completion: .finished)
    return PresentationPipelineError.noPaywallViewController
  }
}
