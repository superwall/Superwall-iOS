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
  var swProductVariablesTemplate: [ProductVariable]
  var orderedSwProducts: [SWProduct]
  var isFreeTrialAvailable: Bool?
  var resetFreeTrialOverride: Bool
}

enum PaywallLogic {
  static func requestHash(
    identifier: String? = nil,
    event: EventData? = nil,
    locale: String = DeviceHelper.shared.locale
  ) -> String {
    let id = identifier ?? event?.name ?? "$called_manually"
    return "\(id)_\(locale)"
  }

  static func handlePaywallError(
    _ error: Error,
    forEvent event: EventData?,
    trackEvent: (Trackable) -> TrackingResult = Superwall.track
  ) -> NSError {
    if let error = error as? CustomURLSession.NetworkError,
      error == .notFound {
      let trackedEvent = InternalSuperwallEvent.PaywallLoad(
        state: .notFound,
        eventData: event
      )
      _ = trackEvent(trackedEvent)
    } else {
      let trackedEvent = InternalSuperwallEvent.PaywallLoad(
        state: .fail,
        eventData: event
      )
      _ = trackEvent(trackedEvent)
    }

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
    return error
  }

  static func getVariablesAndFreeTrial(
    fromProducts products: [Product],
    productsById: [String: SKProduct],
    isFreeTrialAvailableOverride: Bool?,
    isFreeTrialAvailable: @escaping (SKProduct) -> Bool = StoreKitManager.shared.isFreeTrialAvailable(for:)
  ) -> ProductProcessingOutcome {
    var productVariables: [ProductVariable] = []
    var swTemplateProductVariables: [ProductVariable] = []
    var hasFreeTrial: Bool?
    var resetFreeTrialOverride = false
    var orderedSwProducts: [SWProduct] = []

    for product in products {
      // Get skproduct
      guard let appleProduct = productsById[product.id] else {
        continue
      }
      orderedSwProducts.append(appleProduct.swProduct)

      let productVariable = ProductVariable(
        type: product.type,
        attributes: appleProduct.attributesJson
      )
      productVariables.append(productVariable)

      let swTemplateProductVariable = ProductVariable(
        type: product.type,
        attributes: appleProduct.swProductTemplateVariablesJson
      )
      swTemplateProductVariables.append(swTemplateProductVariable)

      if product.type == .primary {
        hasFreeTrial = isFreeTrialAvailable(appleProduct)

        // use the override if it is set
        if let freeTrialOverride = isFreeTrialAvailableOverride {
          hasFreeTrial = freeTrialOverride
          resetFreeTrialOverride = true
        }
      }
    }

    return ProductProcessingOutcome(
      productVariables: productVariables,
      swProductVariablesTemplate: swTemplateProductVariables,
      orderedSwProducts: orderedSwProducts,
      isFreeTrialAvailable: hasFreeTrial,
      resetFreeTrialOverride: resetFreeTrialOverride
    )
  }
}
