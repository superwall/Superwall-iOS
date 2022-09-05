import Foundation
import StoreKit

final class StoreKitManager: NSObject {
	static let shared = StoreKitManager()
  var productsById: [String: SKProduct] = [:]

	private let productsManager = ProductsManager()

	func getVariables(
    forResponse response: PaywallResponse,
    completion: @escaping ([Variable]) -> Void
  ) {
		getProducts(withIds: response.productIds) { result in
      switch result {
      case .success(let productsById):
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

  func processSubstituteProducts(
    _ substituteProducts: PaywallProducts,
    completion: ([String: SKProduct], [Product]) -> Void
  ) {
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

    if let primaryProduct = substituteProducts.primary {
      store(primaryProduct, type: .primary)
    }
    if let secondaryProduct = substituteProducts.secondary {
      store(secondaryProduct, type: .secondary)
    }
    if let tertiaryProduct = substituteProducts.tertiary {
      store(tertiaryProduct, type: .tertiary)
    }

    completion(productsById, products)
  }

	func getProducts(
    withIds ids: [String],
    completion: ((Result<[String: SKProduct], Error>) -> Void)? = nil
  ) {
		let idSet = Set(ids)

		productsManager.products(withIdentifiers: idSet) { [weak self] result in
      switch result {
      case .success(let productsSet):
        guard let self = self else {
          return
        }
        var output: [String: SKProduct] = [:]

        for product in productsSet {
          output[product.productIdentifier] = product
          self.productsById[product.productIdentifier] = product
        }

        completion?(.success(output))
      case .failure(let error):
        completion?(.failure(error))
      }
		}
	}
}
