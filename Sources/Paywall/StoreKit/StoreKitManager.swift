import Foundation
import StoreKit
import TPInAppReceipt

final class StoreKitManager: NSObject {
  // Keep a strong reference to the product request.
	static var shared = StoreKitManager()

	var productsManager = ProductsManager()
  var productsById: [String: SKProduct] = [:]

	func getVariables(
    forResponse response: PaywallResponse,
    completion: @escaping ([Variable]) -> Void
  ) {
		get(productsWithIds: response.productIds) { productsById in
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

	func get(
    productsWithIds: [String],
    completion: (([String: SKProduct]) -> Void)?
  ) {
		let ids = Set<String>(productsWithIds)

		productsManager.products(withIdentifiers: ids) { productsSet in
      var output: [String: SKProduct] = [:]

			for product in productsSet {
				output[product.productIdentifier] = product
				self.productsById[product.productIdentifier] = product
			}

			completion?(output)
		}
	}
}

//
// class StoreKitNetworking: NSObject, SKProductsRequestDelegate {
//
//	var id = UUID().uuidString
//	var request: SKProductsRequest!
//	var didLoadProducts = false
//
//	var onLoadProductsComplete: (() -> ())? = nil
//
//	func get(productsWithIds: [String], completion: @escaping () -> ()) {
//		onLoadProductsComplete = completion
//		didLoadProducts = false
//
//		let productIdentifiers = Set(productsWithIds)
//		request = SKProductsRequest(productIdentifiers: productIdentifiers)
//		request.delegate = self
//		request.start()
//
//		Logger.superwallDebug("Fetching products began ... ")
//
//	}
//
//	var products: [SKProduct] = []
//	func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
//		didLoadProducts = true
//
//		Logger.superwallDebug("Fetching products complete ... ")
//
//
//
//		if !response.products.isEmpty {
//		   products = response.products
//		}
//
//		onLoadProductsComplete!()
//
//		for invalidId in response.invalidProductIdentifiers {
//			Logger.superwallDebug("Invalid product identifier: \(invalidId) Did you set the correct SKProduct id in the Superwall web dashboard?")
//		}
//	}
//
//	func requestDidFinish(_ request: SKRequest) {
//		Logger.superwallDebug("[StoreKitNetworking] requestDidFinish")
//	}
//
//	func request(_ request: SKRequest, didFailWithError error: Error) {
//		Logger.superwallDebug("[StoreKitNetworking] didFailWithError Unable to reach App Store Connect", error)
//	}
//
//
//
// }
