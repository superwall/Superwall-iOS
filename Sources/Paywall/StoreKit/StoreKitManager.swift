import Foundation
import StoreKit
import TPInAppReceipt

class StoreKitManager: NSObject {
	// Keep a strong reference to the product request.
	
	internal static var shared = StoreKitManager()
	
	var productsManager = ProductsManager()
	var productsById = [String: SKProduct]()
		
	func getVariables(forResponse response: PaywallResponse, completion: @escaping ([Variables]) -> ()) {
		get(productsWithIds: response.productIds) { productsById in
			var variables = [Variables]()
			
			for p in response.products {
				if let appleProduct = productsById[p.productId] {
					variables.append(Variables(key: p.product.rawValue, value: JSON(appleProduct.legacyEventData)))
				}
			}
			
			completion(variables)
		}
	}
	
	func get(productsWithIds: [String], completion: (([String: SKProduct]) -> Void)?) {
		
		let ids = Set<String>(productsWithIds)
		
		productsManager.products(withIdentifiers: ids) { productsSet in
			
			var output = [String: SKProduct]()
			
			for p in productsSet {
				output[p.productIdentifier] = p
				self.productsById[p.productIdentifier] = p
			}
			
			completion?(output)
		}
		
	}
	
	
}

//
//class StoreKitNetworking: NSObject, SKProductsRequestDelegate {
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
//	var products = [SKProduct]()
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
//}
