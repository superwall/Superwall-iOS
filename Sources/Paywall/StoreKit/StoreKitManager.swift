import Foundation
import StoreKit

final class StoreKitManager: NSObject {
	static let shared = StoreKitManager()
  var productsById: [String: SKProduct] = [:]
  var swProducts: [SWProduct] = []

	private let productsManager = ProductsManager()

	func getVariables(
    forResponse response: PaywallResponse,
    completion: @escaping ([Variable]) -> Void
  ) {
		getProducts(withIds: response.productIds) { productsById in
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
		}
	}

	func getProducts(
    withIds ids: [String],
    completion: (([String: SKProduct]) -> Void)? = nil
  ) {
		let idSet = Set(ids)

		productsManager.products(withIdentifiers: idSet) { [weak self] productsSet in
      guard let self = self else {
        return
      }
      var output: [String: SKProduct] = [:]

			for product in productsSet {
				output[product.productIdentifier] = product
				self.productsById[product.productIdentifier] = product
			}

      var swProducts: [SWProduct] = []

      for id in ids {
        guard let product = self.productsById[id] else {
          continue
        }
        let swProduct = SWProduct(product: product)
        swProducts.append(swProduct)
      }
      TriggerSessionManager.shared.storeAllProducts(swProducts)
      self.swProducts = swProducts

			completion?(output)
		}
	}
}
