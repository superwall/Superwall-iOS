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
}

enum PaywallLogic {
  static func requestHash(
    identifier: String? = nil,
    placement: PlacementData? = nil,
    locale: String,
    joinedSubstituteProductIds: String?
  ) -> String {
    let id = identifier ?? placement?.name ?? "$called_manually"
    var substitutions = ""
    if let joinedSubstituteProductIds = joinedSubstituteProductIds {
      substitutions = joinedSubstituteProductIds
    }
    return "\(id)_\(locale)_\(substitutions)"
  }

  static func getAppStoreProducts(from products: [Product]) -> [Product] {
    return products.filter {
      if case .appStore = $0.type {
        return true
      }
      return false
    }
  }

  static func handlePaywallError(
    _ error: Error,
    forPlacement placement: PlacementData?,
    trackPlacement: @escaping (Trackable) async -> TrackingResult = Superwall.shared.track
  ) -> NSError {
    if let error = error as? NetworkError,
      error == .notFound {
      let paywallLoad = InternalSuperwallEvent.PaywallLoad(
        state: .notFound,
        placementData: placement
      )
      Task {
        _ = await trackPlacement(paywallLoad)
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
      let paywallLoad = InternalSuperwallEvent.PaywallLoad(
        state: .fail,
        placementData: placement
      )
      Task {
        _ = await trackPlacement(paywallLoad)
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

  static func getProductVariables(
    productItems: [Product],
    productsById: [String: StoreProduct]
  ) -> ProductProcessingOutcome {
    var productVariables: [ProductVariable] = []
    var swProducts: [SWProduct] = []

    for productItem in productItems {
      guard let storeProduct = productsById[productItem.id] else {
        continue
      }

      swProducts.append(storeProduct.swProduct)

      if let name = productItem.name {
        productVariables.append(
          ProductVariable(
            name: name,
            attributes: storeProduct.attributesJson,
            id: storeProduct.productIdentifier,
            hasIntroOffer: storeProduct.hasFreeTrial
          )
        )
      }
    }

    return ProductProcessingOutcome(
      productVariables: productVariables,
      swProducts: swProducts
    )
  }
}
