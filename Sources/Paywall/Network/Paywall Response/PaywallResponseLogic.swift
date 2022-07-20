//
//  PaywallResponseLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 03/03/2022.
//

import Foundation
import StoreKit

struct ResponseIdentifiers: Equatable {
  let paywallId: String?
  var experiment: Experiment?

  static var none: ResponseIdentifiers {
    return  .init(paywallId: nil)
  }
}

struct PaywallErrorResponse {
  let handlers: [PaywallResponseCompletionBlock]
  let error: NSError
}

struct ProductProcessingOutcome {
  var variables: [Variable]
  var productVariables: [ProductVariable]
  var isFreeTrialAvailable: Bool?
  var resetFreeTrialOverride: Bool
}

enum PaywallResponseLogic {
  enum PaywallCachingOutcome {
    case cachedResult(Result<PaywallResponse, NSError>)
    case enqueCompletionBlock(
      hash: String,
      completionBlocks: [PaywallResponseCompletionBlock]
    )
    case setCompletionBlock(hash: String)
  }

  struct TriggerResultOutcome {
    enum Info {
      case paywall(ResponseIdentifiers)
      case holdout(Experiment)
      case unknownEvent(NSError)
      case noRuleMatch
    }
    let info: Info
    var result: TriggerResult?
  }

  static func requestHash(
    identifier: String? = nil,
    event: EventData? = nil,
    locale: String = DeviceHelper.shared.locale
  ) -> String {
    let id = identifier ?? event?.name ?? "$called_manually"
    return "\(id)_\(locale)"
  }

  static func getTriggerResultOutcome(
    presentationInfo: PresentationInfo,
    network: Network = Network.shared,
    triggers: [String: Trigger]
  ) -> TriggerResultOutcome {
    if let eventData = presentationInfo.eventData {
      let triggerAssignmentOutcome = TriggerLogic.assignmentOutcome(
        forEvent: eventData,
        triggers: triggers
      )

      // Confirm any triggers that the user is assigned
      if let confirmableAssignments = triggerAssignmentOutcome.confirmableAssignments {
        network.confirmAssignments(confirmableAssignments)
      }

      return getOutcome(forResult: triggerAssignmentOutcome.result)
    } else {
      let identifiers = ResponseIdentifiers(paywallId: presentationInfo.identifier)
      return TriggerResultOutcome(
        info: .paywall(identifiers)
      )
    }
  }

  private static func getOutcome(
    forResult triggerResult: TriggerResult
  ) -> TriggerResultOutcome {
    switch triggerResult {
    case .paywall(let experiment):
      let identifiers = ResponseIdentifiers(
        paywallId: experiment.variant.paywallId,
        experiment: experiment
      )
      return TriggerResultOutcome(
        info: .paywall(identifiers),
        result: triggerResult
      )
    case let .holdout(experiment):
      return TriggerResultOutcome(
        info: .holdout(experiment),
        result: triggerResult
      )
    case .noRuleMatch:
      return TriggerResultOutcome(
        info: .noRuleMatch,
        result: triggerResult
      )
    case .unknownEvent:
      // create the error
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Trigger Disabled",
          value: "There isn't a paywall configured to show in this context",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "SWTriggerDisabled",
        code: 404,
        userInfo: userInfo
      )
      return TriggerResultOutcome(
        info: .unknownEvent(error),
        result: triggerResult
      )
    }
  }

  // swiftlint:disable:next function_parameter_count
  static func searchForPaywallResponse(
    forEvent event: EventData?,
    withHash hash: String,
    identifiers triggerResponseIds: ResponseIdentifiers?,
    inResultsCache resultsCache: [String: Result<PaywallResponse, NSError>],
    handlersCache: [String: [PaywallResponseCompletionBlock]],
    isDebuggerLaunched: Bool
  ) -> PaywallCachingOutcome {
    // If the response for request exists, return it
    if let result = resultsCache[hash],
      !isDebuggerLaunched {
        switch result {
        case .success(let response):
          var response = response
          response.experiment = triggerResponseIds?.experiment
          return .cachedResult(.success(response))
        case .failure:
          return .cachedResult(result)
        }
    }

    // if the request is in progress, enque the completion handler and return
    if let handlers = handlersCache[hash] {
      return .enqueCompletionBlock(
        hash: hash,
        completionBlocks: handlers
      )
    }

    // If there are no requests in progress, store completion block and continue
    return .setCompletionBlock(hash: hash)
  }

  static func handlePaywallError(
    _ error: Error,
    forEvent event: EventData?,
    withHash hash: String,
    handlersCache: [String: [PaywallResponseCompletionBlock]],
    trackEvent: (Trackable) -> TrackingResult = Paywall.track
  ) -> PaywallErrorResponse? {
    if let error = error as? CustomURLSession.NetworkError,
      error == .notFound {
      let trackedEvent = SuperwallEvent.PaywallResponseLoad(
        state: .notFound,
        eventData: event
      )
      _ = trackEvent(trackedEvent)
    } else {
      let trackedEvent = SuperwallEvent.PaywallResponseLoad(
        state: .fail,
        eventData: event
      )
      _ = trackEvent(trackedEvent)
    }

    if let handlers = handlersCache[hash] {
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Not Found",
          value: "There isn't a paywall configured to show in this context",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "SWPaywallNotFound",
        code: 404,
        userInfo: userInfo
      )

      return PaywallErrorResponse(
        handlers: handlers,
        error: error
      )
    }

    return nil
  }

  static func getVariablesAndFreeTrial(
    fromProducts products: [Product],
    productsById: [String: SKProduct],
    isFreeTrialAvailableOverride: Bool?,
    hasPurchased: @escaping (String) -> Bool = InAppReceipt().hasPurchased(productId:)
  ) -> ProductProcessingOutcome {
    var legacyVariables: [Variable] = []
    var newVariables: [ProductVariable] = []
    var isFreeTrialAvailable: Bool?
    var resetFreeTrialOverride = false

    for product in products {
      // Get skproduct
      guard let appleProduct = productsById[product.id] else {
        continue
      }

      let legacyVariable = Variable(
        key: product.type.rawValue,
        value: appleProduct.eventData
      )
      legacyVariables.append(legacyVariable)

      let productVariable = ProductVariable(
        key: product.type.rawValue,
        value: appleProduct.productVariables
      )
      newVariables.append(productVariable)

      if product.type == .primary {
        isFreeTrialAvailable = appleProduct.hasFreeTrial

        if hasPurchased(product.id),
          appleProduct.hasFreeTrial {
          isFreeTrialAvailable = false
        }
        // use the override if it is set
        if let freeTrialOverride = isFreeTrialAvailableOverride {
          isFreeTrialAvailable = freeTrialOverride
          resetFreeTrialOverride = true
        }
      }
    }

    return ProductProcessingOutcome(
      variables: legacyVariables,
      productVariables: newVariables,
      isFreeTrialAvailable: isFreeTrialAvailable,
      resetFreeTrialOverride: resetFreeTrialOverride
    )
  }
}
