import Foundation
import StoreKit

final class StoreKitManager: NSObject {
	static let shared = StoreKitManager()
  var productsById: [String: SKProduct] = [:]

  private var hasLoadedPurchasedProducts = false
  private let productsManager: ProductsManager
  private struct ProductProcessingResult {
    let responseProductIds: Set<String>
    let substituteProductsById: [String: SKProduct]
    let subsituteProducts: [Product]
  }

  init(productsManager: ProductsManager = ProductsManager()) {
    self.productsManager = productsManager
  }

	func getVariables(
    forResponse response: PaywallResponse,
    completion: @escaping ([Variable]) -> Void
  ) {
		getProducts(withIds: response.productIds) { result in
      switch result {
      case .success(let (productsById, _)):
        var variables: [Variable] = []

        for product in response.products {
          if let skProduct = productsById[product.id] {
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

  func loadPurchasedProducts(completion: @escaping () -> Void) {
    let purchasedProductIds = InAppReceipt.shared.purchasedProductIds
    productsManager.products(withIdentifiers: purchasedProductIds) { [weak self] result in
      switch result {
      case .success(let productsSet):
        guard let self = self else {
          return
        }
        for product in productsSet {
          self.productsById[product.productIdentifier] = product
        }
        InAppReceipt.shared.loadSubscriptionGroupIds()
      case .failure:
        InAppReceipt.shared.failedToLoadPurchasedProducts()
      }
      completion()
    }
  }

  /// Loads products which aren't being substituted.
	func getProducts(
    withIds responseProductIds: [String],
    substituting substituteProducts: PaywallProducts? = nil,
    completion: ((Result<(allProductsById: [String: SKProduct], substituteProducts: [Product]), Error>) -> Void)? = nil
  ) {
    let processingResult = removeAndStore(
      substituteProducts: substituteProducts,
      fromResponseProductIds: responseProductIds
    )

    productsManager.products(withIdentifiers: processingResult.responseProductIds) { [weak self] result in
      switch result {
      case .success(let responseProducts):
        guard let self = self else {
          return
        }
        var allProductsById = processingResult.substituteProductsById

        for responseProduct in responseProducts {
          allProductsById[responseProduct.productIdentifier] = responseProduct
          self.productsById[responseProduct.productIdentifier] = responseProduct
        }
        completion?(.success((allProductsById, processingResult.subsituteProducts)))
      case .failure(let error):
        completion?(.failure(error))
      }
    }
	}

  /// For each product to substitute, this removes the response product at the given index and stores
  /// the substitute product in memory.
  private func removeAndStore(
    substituteProducts: PaywallProducts?,
    fromResponseProductIds responseProductIds: [String]
  ) -> ProductProcessingResult {
    var responseProductIds = responseProductIds
    var substituteProductsById: [String: SKProduct] = [:]
    var products: [Product] = []

    func store(
      _ product: SKProduct,
      type: ProductType
    ) {
      let id = product.productIdentifier
      substituteProductsById[id] = product
      self.productsById[id] = product
      let product = Product(type: type, id: id)
      products.append(product)
    }

    if let primaryProduct = substituteProducts?.primary {
      responseProductIds.remove(safeAt: 0)
      store(primaryProduct, type: .primary)
    }
    if let secondaryProduct = substituteProducts?.secondary {
      responseProductIds.remove(safeAt: 1)
      store(secondaryProduct, type: .secondary)
    }
    if let tertiaryProduct = substituteProducts?.tertiary {
      responseProductIds.remove(safeAt: 2)
      store(tertiaryProduct, type: .tertiary)
    }
    print("resp", responseProductIds, substituteProductsById)
    return ProductProcessingResult(
      responseProductIds: Set(responseProductIds),
      substituteProductsById: substituteProductsById,
      subsituteProducts: products
    )
  }
}
