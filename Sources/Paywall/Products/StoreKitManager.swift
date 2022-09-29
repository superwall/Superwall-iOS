import Foundation
import StoreKit

final class StoreKitManager {
	static let shared = StoreKitManager()
  var productsById: [String: SKProduct] = [:]

  private var hasLoadedPurchasedProducts = false
  private let productsManager: ProductsManager
  private let configManager: ConfigManager
  private struct ProductProcessingResult {
    let productIdsToLoad: Set<String>
    let substituteProductsById: [String: SKProduct]
    let products: [Product]
  }

  init(
    productsManager: ProductsManager = ProductsManager(),
    configManager: ConfigManager = .shared
  ) {
    self.productsManager = productsManager
    self.configManager = configManager
    Task {
      await loadPurchasedProducts()
    }
  }

	func getVariables(
    forResponse response: PaywallResponse,
    completion: @escaping ([Variable]) -> Void
  ) {
		getProducts(withIds: response.productIds) { result in
      switch result {
      case .success(let output):
        var variables: [Variable] = []

        for product in response.products {
          if let skProduct = output.productsById[product.id] {
            let variable = Variable(
              key: product.type.rawValue,
              value: JSON(skProduct.legacyEventData)
            )
            variables.append(variable)
          }
        }

        completion(variables)
      case .failure:
        break
      }
		}
	}

  private func loadPurchasedProducts() async {
    do {
      await configManager.$config.hasValue()
      let purchasedProductIds = InAppReceipt.shared.purchasedProductIds
      let productsSet = try await productsManager.getProducts(withIdentifiers: purchasedProductIds)
      for product in productsSet {
        self.productsById[product.productIdentifier] = product
      }
      InAppReceipt.shared.loadSubscriptionGroupIds()
    } catch {
      InAppReceipt.shared.failedToLoadPurchasedProducts()
    }
  }

  func getProducts(
    withIds responseProductIds: [String],
    responseProducts: [Product] = [],
    substituting substituteProducts: PaywallProducts? = nil
  ) async throws -> (productsById: [String: SKProduct], products: [Product]) {
    return try await withUnsafeThrowingContinuation { continuation in
      getProducts(
        withIds: responseProductIds,
        responseProducts: responseProducts,
        substituting: substituteProducts
      ) { response in
        continuation.resume(with: response)
      }
    }
  }

  /// Gets non-substituted products and returns a
  #warning("Added async wrapped. Convert to async properly and eventually stop using this.")
	func getProducts(
    withIds responseProductIds: [String],
    responseProducts: [Product] = [],
    substituting substituteProducts: PaywallProducts? = nil,
    completion: ((Result<(productsById: [String: SKProduct], products: [Product]), Error>) -> Void)? = nil
  ) {
    let processingResult = removeAndStore(
      substituteProducts: substituteProducts,
      fromResponseProductIds: responseProductIds,
      responseProducts: responseProducts
    )


    productsManager.products(withIdentifiers: processingResult.productIdsToLoad) { [weak self] result in
      switch result {
      case .success(let responseProducts):
        guard let self = self else {
          return
        }
        var productsById = processingResult.substituteProductsById

        for responseProduct in responseProducts {
          productsById[responseProduct.productIdentifier] = responseProduct
          self.productsById[responseProduct.productIdentifier] = responseProduct
        }
        completion?(.success((productsById, processingResult.products)))
      case .failure(let error):
        completion?(.failure(error))
      }
    }
	}

  /// For each product to substitute, this removes the response product at the given index and stores
  /// the substitute product in memory.
  private func removeAndStore(
    substituteProducts: PaywallProducts?,
    fromResponseProductIds responseProductIds: [String],
    responseProducts: [Product]
  ) -> ProductProcessingResult {
    var responseProductIds = responseProductIds
    var substituteProductsById: [String: SKProduct] = [:]
    var products: [Product] = responseProducts

    func storeAndSubstitute(
      _ product: SKProduct,
      type: ProductType,
      index: Int
    ) {
      let id = product.productIdentifier
      substituteProductsById[id] = product
      self.productsById[id] = product
      let product = Product(type: type, id: id)
      products[guarded: index] = product
      responseProductIds.remove(safeAt: index)
    }

    if let primaryProduct = substituteProducts?.primary {
      storeAndSubstitute(
        primaryProduct,
        type: .primary,
        index: 0
      )
    }
    if let secondaryProduct = substituteProducts?.secondary {
      storeAndSubstitute(
        secondaryProduct,
        type: .secondary,
        index: 1
      )
    }
    if let tertiaryProduct = substituteProducts?.tertiary {
      storeAndSubstitute(
        tertiaryProduct,
        type: .tertiary,
        index: 2
      )
    }

    return ProductProcessingResult(
      productIdsToLoad: Set(responseProductIds),
      substituteProductsById: substituteProductsById,
      products: products
    )
  }
}
