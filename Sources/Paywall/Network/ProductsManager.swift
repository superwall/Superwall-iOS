//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  ProductsManager.swift
//
//  Created by Andrés Boedo on 7/14/20.
//
import Foundation
import StoreKit

class ProductsManager: NSObject {

	private let productsRequestFactory: ProductsRequestFactory
	private var cachedProductsByIdentifier: [String: SKProduct] = [:]
	private let queue = DispatchQueue(label: "ProductsManager")
	private var productsByRequests: [SKRequest: Set<String>] = [:]
	private var completionHandlers: [Set<String>: [(Set<SKProduct>) -> Void]] = [:]

	init(productsRequestFactory: ProductsRequestFactory = ProductsRequestFactory()) {
		self.productsRequestFactory = productsRequestFactory
	}

	func products(withIdentifiers identifiers: Set<String>,
				  completion: @escaping (Set<SKProduct>) -> Void) {
		guard identifiers.count > 0 else {
			completion([])
			return
		}
		queue.async { [self] in
			let productsAlreadyCached = self.cachedProductsByIdentifier.filter { key, _ in identifiers.contains(key) }
			if productsAlreadyCached.count == identifiers.count {
				let productsAlreadyCachedSet = Set(productsAlreadyCached.values)
				Logger.debug(logLevel: .debug, scope: .productsManager, message: "Products Already Cached", info: ["product_ids": identifiers], error: nil)
				completion(productsAlreadyCachedSet)
				return
			}

			if let existingHandlers = self.completionHandlers[identifiers] {
				Logger.debug(logLevel: .debug, scope: .productsManager, message: "Found Existing Product Request", info: ["product_ids": identifiers], error: nil)
				self.completionHandlers[identifiers] = existingHandlers + [completion]
				return
			}

			Logger.debug(logLevel: .debug, scope: .productsManager, message: "Creating New Request", info: ["product_ids": identifiers], error: nil)
			let request = self.productsRequestFactory.request(productIdentifiers: identifiers)
			request.delegate = self
			self.completionHandlers[identifiers] = [completion]
			self.productsByRequests[request] = identifiers
			request.start()
		}
	}

	func cacheProduct(_ product: SKProduct) {
		queue.async {
			self.cachedProductsByIdentifier[product.productIdentifier] = product
		}
	}

}

extension ProductsManager: SKProductsRequestDelegate {

	func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
		queue.async { [self] in
			Logger.debug(logLevel: .debug, scope: .productsManager, message: "Fetched Product", info: ["request": request.debugDescription], error: nil)
			guard let requestProducts = self.productsByRequests[request] else {
				Logger.debug(logLevel: .warn, scope: .productsManager, message: "Requested Products Not Found", info: ["request": request.debugDescription], error: nil)
				return
			}
			guard let completionBlocks = self.completionHandlers[requestProducts] else {
				Logger.debug(logLevel: .error, scope: .productsManager, message: "Completion Handler Not Found", info: ["products": requestProducts, "request": request.debugDescription], error: nil)
				return
			}

			self.completionHandlers.removeValue(forKey: requestProducts)
			self.productsByRequests.removeValue(forKey: request)

			self.cacheProducts(response.products)
			for completion in completionBlocks {
				completion(Set(response.products))
			}
		}
	}

	func requestDidFinish(_ request: SKRequest) {
		Logger.debug(logLevel: .debug, scope: .productsManager, message: "Request Complete", info: ["request": request.debugDescription], error: nil)
		request.cancel()
	}

	func request(_ request: SKRequest, didFailWithError error: Error) {
		queue.async { [self] in
			Logger.debug(logLevel: .error, scope: .productsManager, message: "Request Failed", info: ["request": request.debugDescription], error: error)
			guard let products = self.productsByRequests[request] else {
				Logger.debug(logLevel: .error, scope: .productsManager, message: "Requested Products Not Found", info: ["request": request.debugDescription], error: error)
				return
			}
			guard let completionBlocks = self.completionHandlers[products] else {
				Logger.debug(logLevel: .error, scope: .productsManager, message: "Callback Not Found for Failed Request", info: ["request": request.debugDescription], error: error)
				return
			}

			self.completionHandlers.removeValue(forKey: products)
			self.productsByRequests.removeValue(forKey: request)
			for completion in completionBlocks {
				completion(Set())
			}
		}
		request.cancel()
	}

}

private extension ProductsManager {

	func cacheProducts(_ products: [SKProduct]) {
		let productsByIdentifier = products.reduce(into: [:]) { resultDict, product in
			resultDict[product.productIdentifier] = product
		}

		cachedProductsByIdentifier = cachedProductsByIdentifier.merging(productsByIdentifier)
	}

}


class ProductsRequestFactory {

	func request(productIdentifiers: Set<String>) -> SKProductsRequest {
		return SKProductsRequest(productIdentifiers: productIdentifiers)
	}

}
