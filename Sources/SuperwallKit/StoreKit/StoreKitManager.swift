// swiftlint:disable function_body_length

import Foundation
import StoreKit
import Combine

actor StoreKitManager {
  /// Retrieves products from storekit.
  private let productsManager: ProductsManager

  /// Cached products keyed by their Apple product identifier. Custom and
  /// test products live here too, keyed by their unique IDs.
  private(set) var productsById: [String: StoreProduct] = [:]

  /// Cached products keyed by composite Product ID (`Product.id`). When two
  /// Superwall Products share the same Apple product identifier but differ
  /// in `billingPlanType`, both entries appear here, each wrapping a
  /// `StoreProduct` clone with the matching billing plan attached. Built
  /// from `productsById` during paywall product loading.
  private(set) var productsByCompositeId: [String: StoreProduct] = [:]

  func setProduct(_ product: StoreProduct, forIdentifier identifier: String) {
    productsById[identifier] = product
  }
  private struct ProductProcessingResult {
    let productIdsToLoad: Set<String>
    let substituteProductsById: [String: StoreProduct]
    let productItems: [Product]
  }

  init(productsManager: ProductsManager) {
    self.productsManager = productsManager
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
      guard let storeProduct = output.productsByCompositeId[productItem.id] else {
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

  // swiftlint:disable:next cyclomatic_complexity
  func getProducts(
    forPaywall paywall: Paywall?,
    placement: PlacementData?,
    substituting substituteProductsByLabel: [String: ProductOverride]? = nil,
    isTestMode: Bool = false
  ) async throws -> (
    productsByCompositeId: [String: StoreProduct],
    productItems: [Product]
  ) {
    // In test mode, use cached test products instead of fetching from StoreKit.
    // Cached test products are keyed by Apple identifier, so composite IDs that
    // include a billing-plan suffix (e.g. `com.app.annual:MONTHLY`) must be
    // resolved via the inner Apple ID.
    if isTestMode {
      var productItems: [Product] = []
      for original in paywall?.products ?? [] {
        let cached: StoreProduct?
        if case .appStore(let appStoreProduct) = original.type {
          cached = productsById[appStoreProduct.id]
        } else {
          cached = productsById[original.id]
        }
        if let cached = cached {
          productItems.append(
            Product(
              name: original.name,
              type: original.type,
              id: original.id,
              entitlements: cached.entitlements
            )
          )
        } else {
          productItems.append(original)
        }
      }

      // Build the composite-ID map. For App Store products, clone the cached
      // StoreProduct with the slot's billing plan attached so billing-plan
      // scenarios route correctly in test mode too.
      var testProductsByCompositeId: [String: StoreProduct] = [:]
      for productItem in productItems {
        if case .appStore(let appStoreProduct) = productItem.type,
          let base = productsById[appStoreProduct.id] {
          let clone = base.copyForCompositeProduct(
            billingPlanType: appStoreProduct.billingPlanType
          )
          testProductsByCompositeId[productItem.id] = clone
        } else if let base = productsById[productItem.id] {
          testProductsByCompositeId[productItem.id] = base
        }
      }

      testProductsByCompositeId.forEach { id, product in
        self.productsByCompositeId[id] = product
      }

      return (testProductsByCompositeId, productItems)
    }

    // 1. Compute fetch IDs (Apple product identifiers, deduped) = paywall
    //    Apple IDs - byProduct IDs + byId IDs. We fetch by Apple ID, not by
    //    composite ID, because `StoreKit.Product.products(for:)` only
    //    accepts Apple product identifiers.
    let paywallAppleIDs = Set(paywall?.appStoreProductIdentifiers ?? [])
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
    let idsToFetch = paywallAppleIDs
      .subtracting(byProductIDs)
      .union(byIdIDs)

    // 2. Fetch exactly that set once
    let fetchedProducts = try await productsManager.products(
      identifiers: idsToFetch,
      forPaywall: paywall,
      placement: placement
    )

    // 3. Build lookup from Apple identifier → StoreProduct
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

    // 6. Cache by Apple ID in memory
    productsById.forEach { id, product in
      self.productsById[id] = product
    }

    // 7. Build the composite-ID map. For each App Store Product on the
    //    paywall, clone the underlying StoreProduct and attach the slot's
    //    billing plan so price/period accessors route correctly and the
    //    purchase pipeline can pick the plan up later. Two composite entries
    //    sharing an Apple ID get two independent clones.
    var productsByCompositeId: [String: StoreProduct] = [:]
    for productItem in productItems {
      guard case .appStore(let appStoreProduct) = productItem.type,
        let base = productsById[appStoreProduct.id] else {
        continue
      }
      let clone = base.copyForCompositeProduct(billingPlanType: appStoreProduct.billingPlanType)
      productsByCompositeId[productItem.id] = clone
      self.productsByCompositeId[productItem.id] = clone
    }

    return (productsByCompositeId, productItems)
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
