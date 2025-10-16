//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation
import Combine

extension Superwall {
  /// Requests the paywall view controller to present.
  ///
  /// - Parameters:
  ///   - request: The presentation request.
  ///   - audienceOutcome: The outcome from evaluating audience filters.
  ///   - debugInfo: Information to help with debugging.
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  ///   - dependencyContainer: Used with testing only.
  ///
  /// - Returns: A ``PaywallViewController``.
  /// - throws: An error if unable to retrieve paywall or a paywall is
  /// already presented.
  func getPaywallViewController(
    request: PresentationRequest,
    audienceOutcome: AudienceFilterEvaluationOutcome,
    debugInfo: [String: Any],
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>? = nil,
    dependencyContainer: DependencyContainer
  ) async throws -> PaywallViewController {
    let experiment = try await getExperiment(
      request: request,
      audienceOutcome: audienceOutcome,
      debugInfo: debugInfo,
      paywallStatePublisher: paywallStatePublisher,
      storage: dependencyContainer.storage
    )

    let responseIdentifiers = ResponseIdentifiers(
      paywallId: experiment.variant.paywallId,
      experiment: experiment
    )

    let productOverrides: [String: ProductOverride]? =
      request.paywallOverrides?
        .productsByName
        .mapValues(ProductOverride.byProduct)
      ?? options.paywalls
        .overrideProductsByName?
        .mapValues(ProductOverride.byId)

    let paywallRequest = dependencyContainer.makePaywallRequest(
      placementData: request.presentationInfo.placementData,
      responseIdentifiers: responseIdentifiers,
      overrides: .init(
        products: productOverrides,
        isFreeTrial: request.presentationInfo.freeTrialOverride,
        featureGatingBehavior: request.paywallOverrides?.featureGatingBehavior
      ),
      isDebuggerLaunched: request.flags.isDebuggerLaunched,
      presentationSourceType: request.presentationSourceType
    )
    do {
      let isForPresentation = !request.flags.type.isGettingPresentationResult
      let delegate = request.flags.type.getPaywallVcDelegateAdapter()

      Logger.debug(
        logLevel: .debug,
        scope: .paywallPresentation,
        message: "Getting paywall from request",
        info: debugInfo.merging([
          "paywallId": responseIdentifiers.paywallId ?? "nil",
          "experimentId": responseIdentifiers.experiment?.id ?? "nil"
        ])
      )

      let paywall = try await dependencyContainer.paywallManager.getPaywall(from: paywallRequest)

      Logger.debug(
        logLevel: .debug,
        scope: .paywallPresentation,
        message: "Successfully got paywall, creating view controller",
        info: debugInfo.merging([
          "paywallId": paywall.identifier,
          "paywallName": paywall.name
        ])
      )

      let paywallViewController = try await dependencyContainer.paywallManager.getViewController(
        for: paywall,
        isDebuggerLaunched: paywallRequest.isDebuggerLaunched,
        isForPresentation: isForPresentation,
        isPreloading: false,
        delegate: delegate
      )

      Logger.debug(
        logLevel: .debug,
        scope: .paywallPresentation,
        message: "Successfully created paywall view controller",
        info: debugInfo
      )

      return paywallViewController
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .paywallPresentation,
        message: "GetPaywallVC caught error before conversion to noPaywallViewController",
        info: debugInfo.merging([
          "errorDomain": (error as NSError).domain,
          "errorCode": (error as NSError).code,
          "errorDescription": error.localizedDescription
        ]),
        error: error
      )
      throw await presentationFailure(error, request, debugInfo, paywallStatePublisher)
    }
  }

  private func presentationFailure(
    _ error: Error,
    _ request: PresentationRequest,
    _ debugInfo: [String: Any],
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>?
  ) async -> Error {
    if !request.flags.type.isGettingPresentationResult {
      Logger.debug(
        logLevel: .error,
        scope: .paywallPresentation,
        message: "Error Getting Paywall View Controller",
        info: debugInfo,
        error: error
      )
    }
    paywallStatePublisher?.send(.presentationError(error))
    paywallStatePublisher?.send(completion: .finished)
    return PresentationPipelineError.noPaywallViewController
  }
}
