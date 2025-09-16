//
//  ProductsFetcherSK2.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 19/09/2024.
//

import Foundation
import StoreKit

enum ProductsFetcherSK2Error: LocalizedError {
  case noProductsFound(Set<String>)

  var errorDescription: String? {
    switch self {
    case .noProductsFound(let identifiers):
      return "Could not load products with identifiers: \(identifiers)"
    }
  }
}

@available(iOS 15.0, *)
final actor ProductsFetcherSK2: ProductFetchable, Sendable {
  private unowned let entitlementsInfo: EntitlementsInfo
  private let numberOfRetries: Int

  init(
    entitlementsInfo: EntitlementsInfo,
    numberOfRetries: Int = 10
  ) {
    self.entitlementsInfo = entitlementsInfo
    self.numberOfRetries = numberOfRetries
  }

  func products(
    identifiers: Set<String>,
    forPaywall paywall: Paywall?,
    placement: PlacementData?
  ) async throws -> Set<StoreProduct> {
    return try await fetchProducts(
      identifiers: identifiers,
      paywall: paywall,
      placement: placement,
      retriesLeft: numberOfRetries
    )
  }

  private func fetchProducts(
    identifiers: Set<String>,
    paywall: Paywall?,
    placement: PlacementData?,
    retriesLeft: Int
  ) async throws -> Set<StoreProduct> {
    do {
      let sk2Products = try await StoreKit.Product.products(for: identifiers)

      if sk2Products.isEmpty,
        !identifiers.isEmpty {
        var errorMessage = "Could not load products"
        if let paywallName = paywall?.name {
          errorMessage += " from paywall \"\(paywallName)\""
        }
        Logger.debug(
          logLevel: .error,
          scope: .productsManager,
          message: "\(errorMessage). Visit https://superwall.com/l/missing-products to diagnose.",
          info: ["product_ids": identifiers.description]
        )
        throw ProductFetchingError.noProductsFound(identifiers)
      }

      let storeProducts = Set(sk2Products.map {
        let entitlements = entitlementsInfo.byProductId($0.id)
        return StoreProduct(sk2Product: $0, entitlements: entitlements)
      })
      return storeProducts
    } catch {
      if error is ProductFetchingError {
        throw error
      }
      if retriesLeft <= 0 {
        throw error
      } else {
        // Wait 3 seconds before retrying
        try await Task.sleep(nanoseconds: 3_000_000_000)

        let retryCount = numberOfRetries - (retriesLeft - 1)
        if let paywall = paywall {
          let productLoadRetry = InternalSuperwallEvent.PaywallProductsLoad(
            state: .retry(retryCount),
            paywallInfo: paywall.getInfo(fromPlacement: placement),
            placementData: placement
          )
          await Superwall.shared.track(productLoadRetry)
        }
        Logger.debug(
          logLevel: .info,
          scope: .productsManager,
          message: "Retrying product request.",
          info: [
            "retry_count": retryCount,
            "product_ids": identifiers
          ],
          error: error
        )

        return try await fetchProducts(
          identifiers: identifiers,
          paywall: paywall,
          placement: placement,
          retriesLeft: retriesLeft - 1
        )
      }
    }
  }
}
