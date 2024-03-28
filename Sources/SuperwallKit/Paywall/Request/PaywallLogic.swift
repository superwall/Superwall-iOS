//
//  PaywallLogic.swift
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

struct ProductProcessingOutcome {
  var productVariables: [ProductVariable]
  var swProducts: [SWProduct]
  var isFreeTrialAvailable: Bool
}

enum PaywallLogic {
  static func requestHash(
    identifier: String? = nil,
    event: EventData? = nil,
    locale: String,
    joinedSubstituteProductIds: String?
  ) -> String {
    let id = identifier ?? event?.name ?? "$called_manually"
    var substitutions = ""
    if let joinedSubstituteProductIds = joinedSubstituteProductIds {
      substitutions = joinedSubstituteProductIds
    }
    return "\(id)_\(locale)_\(substitutions)"
  }

  static func handlePaywallError(
    _ error: Error,
    forEvent event: EventData?,
    trackEvent: @escaping (Trackable) async -> TrackingResult = Superwall.shared.track
  ) -> NSError {
    if let error = error as? NetworkError,
      error == .notFound {
      let trackedEvent = InternalSuperwallEvent.PaywallLoad(
        state: .notFound,
        eventData: event
      )
      Task {
        _ = await trackEvent(trackedEvent)
      }
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Not Found",
          value: "There isn't a paywall configured to show in this context.",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "SWKPaywallNotFound",
        code: 404,
        userInfo: userInfo
      )
      return error
    } else {
      let trackedEvent = InternalSuperwallEvent.PaywallLoad(
        state: .fail,
        eventData: event
      )
      Task {
        _ = await trackEvent(trackedEvent)
      }
      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "No Paywall",
          value: "The paywall failed to load.",
          comment: ""
        )
      ]
      let error = NSError(
        domain: "SWKPresentationError",
        code: 107,
        userInfo: userInfo
      )
      return error
    }
  }

  static func getVariablesAndFreeTrial(
    productItems: [ProductItem],
    productsById: [String: StoreProduct],
    isFreeTrialAvailableOverride: Bool?,
    isFreeTrialAvailable: @escaping (StoreProduct) async -> Bool
  ) async -> ProductProcessingOutcome {

    var productVariables: [ProductVariable] = []
    var swProducts: [SWProduct] = []
    var hasFreeTrial = false

    for productItem in productItems {
      guard let storeProduct = productsById[productItem.id] else {
        continue
      }

      swProducts.append(storeProduct.swProduct)
      productVariables.append(
        ProductVariable(
          name: productItem.name,
          attributes: storeProduct.attributesJson
        )
      )

      // Check for a free trial only if we haven't already found one
      if !hasFreeTrial {
        hasFreeTrial = await isFreeTrialAvailable(storeProduct)
      }
    }

    // use the override if it is set
    if let freeTrialOverride = isFreeTrialAvailableOverride {
      hasFreeTrial = freeTrialOverride
    }

    return ProductProcessingOutcome(
      productVariables: productVariables,
      swProducts: swProducts,
      isFreeTrialAvailable: hasFreeTrial
    )
  }
}
