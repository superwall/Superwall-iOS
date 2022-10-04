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

struct ProductProcessingOutcome {
  var variables: [Variable]
  var productVariables: [ProductVariable]
  var orderedSwProducts: [SWProduct]
  var isFreeTrialAvailable: Bool?
  var resetFreeTrialOverride: Bool
}

enum PaywallResponseLogic {
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
      let trackedEvent = InternalSuperwallEvent.PaywallResponseLoad(
        state: .notFound,
        eventData: event
      )
      _ = trackEvent(trackedEvent)
    } else {
      let trackedEvent = InternalSuperwallEvent.PaywallResponseLoad(
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
    var legacyVariables: [Variable] = []
    var newVariables: [ProductVariable] = []
    var hasFreeTrial: Bool?
    var resetFreeTrialOverride = false
    var orderedSwProducts: [SWProduct] = []

    for product in products {
      // Get skproduct
      guard let appleProduct = productsById[product.id] else {
        continue
      }
      orderedSwProducts.append(appleProduct.swProduct)

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
        hasFreeTrial = isFreeTrialAvailable(appleProduct)

        // use the override if it is set
        if let freeTrialOverride = isFreeTrialAvailableOverride {
          hasFreeTrial = freeTrialOverride
          resetFreeTrialOverride = true
        }
      }
    }

    return ProductProcessingOutcome(
      variables: legacyVariables,
      productVariables: newVariables,
      orderedSwProducts: orderedSwProducts,
      isFreeTrialAvailable: hasFreeTrial,
      resetFreeTrialOverride: resetFreeTrialOverride
    )
  }
}
