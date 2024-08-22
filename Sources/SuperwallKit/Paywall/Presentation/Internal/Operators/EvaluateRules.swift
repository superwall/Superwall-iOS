//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation

extension Superwall {
  /// Evaluates the rules from the campaign that the event belongs to.
  ///
  /// - Parameter request: The presentation request
  /// - Returns: An `AudienceEvaluationOutcome` object containing the trigger result,
  /// confirmable assignment, and unsaved occurrence.
  func evaluateAudienceFilters(
    from request: PresentationRequest
  ) async throws -> AudienceEvaluationOutcome {
    if let eventData = request.presentationInfo.eventData {
      let audienceFilterLogic = AudienceFilterLogic(
        configManager: dependencyContainer.configManager,
        storage: dependencyContainer.storage,
        factory: dependencyContainer
      )
      return await audienceFilterLogic.evaluate(
        forEvent: eventData,
        triggers: dependencyContainer.configManager.triggersByEventName
      )
    } else {
      // Called if the debugger is shown.
      guard let paywallId = request.presentationInfo.identifier else {
        // This error will never be thrown. Just preferring this
        // to force unwrapping.
        throw PresentationPipelineError.noPaywallViewController
      }
      return AudienceEvaluationOutcome(
        triggerResult: .paywall(.presentById(paywallId))
      )
    }
  }
}
