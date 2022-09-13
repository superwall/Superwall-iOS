import Foundation
import StoreKit

final class StoreKitManager: NSObject {
	static let shared = StoreKitManager()
  var productsById: [String: SKProduct] = [:]

  private var hasLoadedPurchasedProducts = false
	private let productsManager = ProductsManager()

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
    completion: ((Result<(productsById: [String: SKProduct], substituteProducts: [Product]), Error>) -> Void)? = nil
  ) {
    let (responseProductIds, substituteProductsById, products) = processProducts(
      responseProductIds: responseProductIds,
      substituteProducts: substituteProducts
    )

		productsManager.products(withIdentifiers: responseProductIds) { [weak self] result in
      switch result {
      case .success(let productsSet):
        guard let self = self else {
          return
        }
        var productsById = substituteProductsById

        for product in productsSet {
          productsById[product.productIdentifier] = product
          self.productsById[product.productIdentifier] = product
        }
        completion?(.success((productsById, products)))
      case .failure(let error):
        completion?(.failure(error))
      }
		}
	}

  private func processProducts(
    responseProductIds: [String],
    substituteProducts: PaywallProducts?
  ) -> (reponseProductIds: Set<String>, productsById: [String: SKProduct], products: [Product]) {
    var responseProductIds = responseProductIds
    var productsById: [String: SKProduct] = [:]
    var products: [Product] = []

    func store(
      _ product: SKProduct,
      type: ProductType
    ) {
      let id = product.productIdentifier
      productsById[id] = product
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

    return (Set(responseProductIds), productsById, products)
  }
}
