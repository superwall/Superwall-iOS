import Foundation
import StoreKit
import Combine

actor StoreKitManager {
  /// Retrieves products from storekit.
  private let productsFetcher: ProductsFetcherSK1

  private(set) var productsById: [String: StoreProduct] = [:]
  private struct ProductProcessingResult {
    let productIdsToLoad: Set<String>
    let substituteProductsById: [String: StoreProduct]
    let productItems: [ProductItem]
  }

  init(productsFetcher: ProductsFetcherSK1) {
    self.productsFetcher = productsFetcher
  }

  func getProductVariables(for paywall: Paywall) async -> [ProductVariable] {
    guard let output = try? await getProducts(
      forPaywall: paywall,
      event: nil
    ) else {
      return []
    }

    var productAttributes: [ProductVariable] = []

    // Add the StoreProduct attributes for each product at its corresponding index
    paywall.productItems.forEach { productItem in
      guard let storeProduct = output.productsById[productItem.id] else {
        return
      }
      productAttributes.append(
        ProductVariable(
          name: productItem.name,
          attributes: storeProduct.attributesJson
        )
      )
    }

    return productAttributes
  }

  func getProducts(
    forPaywall paywall: Paywall?,
    event: EventData?,
    substituting substituteProductsByLabel: [String: StoreProduct]? = nil
  ) async throws -> (productsById: [String: StoreProduct], productItems: [ProductItem]) {
    let processingResult = removeAndStore(
      substituteProductsByLabel: substituteProductsByLabel,
      paywallProductIds: paywall?.productIds ?? [],
      productItems: paywall?.productItems ?? []
    )

    let products = try await productsFetcher.products(
      identifiers: processingResult.productIdsToLoad,
      forPaywall: paywall,
      event: event
    )

    var productsById = processingResult.substituteProductsById

    for product in products {
      productsById[product.productIdentifier] = product
      self.productsById[product.productIdentifier] = product
    }

    return (productsById, processingResult.productItems)
  }

  /// For each product to substitute, this replaces the paywall product at the given index and stores
  /// the substitute product in memory.
  private func removeAndStore(
    substituteProductsByLabel: [String: StoreProduct]?,
    paywallProductIds: [String],
    productItems: [ProductItem]
  ) -> ProductProcessingResult {
    /// Product IDs to load in the future. Initialised to the given paywall products.
    var productIdsToLoad = paywallProductIds

    /// Products to substitute, initially empty.
    var substituteProductsById: [String: StoreProduct] = [:]

    /// The final product IDs by index. Initialised with the ones from the paywall object.
    var productItems: [ProductItem] = productItems

    // If there are no substitutions, return what we have
    guard let substituteProductsByLabel = substituteProductsByLabel else {
      return ProductProcessingResult(
        productIdsToLoad: Set(productIdsToLoad),
        substituteProductsById: substituteProductsById,
        productItems: productItems
      )
    }

    // Otherwise, iterate over each substitute product
    for (name, product) in substituteProductsByLabel {
      let productId = product.productIdentifier

      // Map substitute product by its ID.
      substituteProductsById[productId] = product

      // Store the substitute product by id in the class' dictionary
      self.productsById[productId] = product

      if let index = productItems.firstIndex(where: { $0.name == name }) {
        // Update the product ID at the found index
        productItems[index] = ProductItem(
          name: name,
          type: .appStore(.init(id: productId))
        )
      } else {
        // If it isn't found, just append to the list.
        productItems.append(
          ProductItem(
            name: name,
            type: .appStore(.init(id: productId))
          )
        )
      }

      // Make sure we don't load the substitute product id
      productIdsToLoad.removeAll { $0 == productId }
    }

    return ProductProcessingResult(
      productIdsToLoad: Set(productIdsToLoad),
      substituteProductsById: substituteProductsById,
      productItems: productItems
    )
  }
}
