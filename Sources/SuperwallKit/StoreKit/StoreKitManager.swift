// swiftlint:disable function_body_length

import Foundation
import StoreKit
import Combine

actor StoreKitManager {
  /// Retrieves products from storekit.
  private let productsManager: ProductsManager
  var testModeManager: TestModeManager?

  private(set) var productsById: [String: StoreProduct] = [:]
  private struct ProductProcessingResult {
    let productIdsToLoad: Set<String>
    let substituteProductsById: [String: StoreProduct]
    let productItems: [Product]
  }

  init(productsManager: ProductsManager) {
    self.productsManager = productsManager
  }

  func setTestModeManager(_ manager: TestModeManager) {
    self.testModeManager = manager
  }

  func getProductVariables(for paywall: Paywall) async -> [ProductVariable] {
    guard let output = try? await getProducts(
      forPaywall: paywall,
      placement: nil
    ) else {
      return []
    }

    var productAttributes: [ProductVariable] = []

    // Add the StoreProduct attributes for each product at its corresponding index
    paywall.appStoreProducts.forEach { productItem in
      guard let storeProduct = output.productsById[productItem.id] else {
        return
      }

      if let name = productItem.name {
        productAttributes.append(
          ProductVariable(
            name: name,
            attributes: storeProduct.attributesJson,
            id: storeProduct.productIdentifier,
            hasIntroOffer: storeProduct.hasFreeTrial
          )
        )
      }
    }

    return productAttributes
  }

  func getProducts(
    forPaywall paywall: Paywall?,
    placement: PlacementData?,
    substituting substituteProductsByLabel: [String: ProductOverride]? = nil
  ) async throws -> (
    productsById: [String: StoreProduct],
    productItems: [Product]
  ) {
    // In test mode, use cached test products instead of fetching from StoreKit
    if testModeManager?.isTestMode == true {
      var testProductsById: [String: StoreProduct] = [:]
      for (id, product) in productsById {
        testProductsById[id] = product
      }

      var productItems: [Product] = []
      for original in paywall?.products ?? [] {
        if let id = original.id, let product = testProductsById[id] {
          productItems.append(
            Product(
              name: original.name,
              type: original.type,
              id: id,
              entitlements: product.entitlements
            )
          )
        } else {
          productItems.append(original)
        }
      }

      testProductsById.forEach { id, product in
        self.productsById[id] = product
      }

      return (testProductsById, productItems)
    }

    // 1. Compute fetch IDs = paywall IDs - byProduct IDs + byId IDs
    let paywallIDs = Set(paywall?.appStoreProductIds ?? [])
    let byIdIDs: Set<String> = Set(substituteProductsByLabel?.values.compactMap {
      if case .byId(let id) = $0 {
        return id
      } else {
        return nil
      }
    } ?? [])
    let byProductIDs: Set<String> = Set(substituteProductsByLabel?.values.compactMap {
      if case .byProduct(let product) = $0 {
        return product.productIdentifier
      } else {
        return nil
      }
    } ?? [])
    let idsToFetch = paywallIDs
      .subtracting(byProductIDs)
      .union(byIdIDs)

    // 2. Fetch exactly that set once
    let fetchedProducts = try await productsManager.products(
      identifiers: idsToFetch,
      forPaywall: paywall,
      placement: placement
    )

    // 3. Build lookup from identifier → StoreProduct
    var productsById = Dictionary(
      uniqueKeysWithValues: fetchedProducts.map { ($0.productIdentifier, $0) }
    )

    // 4. Inject any .byProduct overrides directly
    substituteProductsByLabel?.forEach { _, override in
      if case .byProduct(let product) = override {
        productsById[product.productIdentifier] = product
      }
    }

    // 5. Rebuild the paywall’s Product list, applying overrides
    var productItems: [Product] = []
    for original in paywall?.products ?? [] {
      guard let name = original.name else {
        productItems.append(original)
        continue
      }

      if let override = substituteProductsByLabel?[name] {
        switch override {
        case .byId(let id):
          if let product = productsById[id] {
            productItems.append(
              Product(
                name: name,
                type: .appStore(.init(id: id)),
                id: id,
                entitlements: product.entitlements
              )
            )
          } else {
            productItems.append(original)
          }
        case .byProduct(let product):
          let id = product.productIdentifier
          productItems.append(
            Product(
              name: name,
              type: .appStore(.init(id: id)),
              id: id,
              entitlements: product.entitlements
            )
          )
        }
      } else {
        productItems.append(original)
      }
    }

    // 6. Cache in memory
    productsById.forEach { id, product in
      self.productsById[id] = product
    }

    return (productsById, productItems)
  }

  func preloadOverrides(_ overrides: [ProductOverride]) async {
    let allIds: Set<String> = Set(overrides.compactMap {
      if case .byId(let id) = $0 {
        return id
      } else {
        return nil
      }
    })

    // Subtract out anything already in our cache
    let idsToFetch = allIds.filter { self.productsById[$0] == nil }

    // Nothing new to load?
    if idsToFetch.isEmpty {
      return
    }

    guard let fetchedProducts = try? await productsManager.products(
      identifiers: idsToFetch,
      forPaywall: nil,
      placement: nil
    ) else {
      return
    }
    let productsById = Dictionary(
      uniqueKeysWithValues: fetchedProducts.map { ($0.productIdentifier, $0) }
    )
    productsById.forEach { id, product in
      self.productsById[id] = product
    }
  }
}
