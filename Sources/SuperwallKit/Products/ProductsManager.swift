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
  static let shared = ProductsManager()

	private var cachedProductsByIdentifier: [String: SKProduct] = [:]
	private let queue = DispatchQueue(label: "com.superwall.ProductsManager")
	private var productsByRequests: [SKRequest: Set<String>] = [:]
  typealias ProductRequestCompletionBlock = (Result<Set<SKProduct>, Error>) -> Void
	private var completionHandlers: [Set<String>: [ProductRequestCompletionBlock]] = [:]

  func getProducts(identifiers: Set<String>) async throws -> Set<SKProduct> {
    return try await withCheckedThrowingContinuation { continuation in
      products(withIdentifiers: identifiers) { result in
        continuation.resume(with: result)
      }
    }
  }

	private func products(
    withIdentifiers identifiers: Set<String>,
    completion: @escaping ProductRequestCompletionBlock
  ) {
    // Return if there aren't any product IDs.
		if identifiers.isEmpty {
      completion(.success([]))
			return
		}

		queue.async { [self] in
      // If products already cached, return them
      let productsAlreadyCached = self.cachedProductsByIdentifier.filter { key, _ in identifiers.contains(key) }

      if productsAlreadyCached.count == identifiers.count {
        let productsAlreadyCachedSet = Set(self.cachedProductsByIdentifier.map { $0.value })
				Logger.debug(
          logLevel: .debug,
          scope: .productsManager,
          message: "Products Already Cached",
          info: ["product_ids": identifiers],
          error: nil
        )
        DispatchQueue.main.async {
          completion(.success(productsAlreadyCachedSet))
        }
				return
			}

      // If there are any existing completion handlers, it means there have already been some requests for products but they haven't loaded. Queue up this request's completion handler.
			if let existingHandlers = self.completionHandlers[identifiers] {
				Logger.debug(
          logLevel: .debug,
          scope: .productsManager,
          message: "Found Existing Product Request",
          info: ["product_ids": identifiers],
          error: nil
        )
				self.completionHandlers[identifiers] = existingHandlers + [completion]
				return
			}

      // Otherwise request products and enqueue the completion handler.
      // When the request finishes, all completion handlers will get called with the products.
			Logger.debug(
        logLevel: .debug,
        scope: .productsManager,
        message: "Creating New Request",
        info: ["product_ids": identifiers],
        error: nil
      )
			let request = SKProductsRequest(productIdentifiers: identifiers)
			request.delegate = self
			self.completionHandlers[identifiers] = [completion]
			self.productsByRequests[request] = identifiers
			request.start()
		}
	}

  private func cacheProducts(_ products: [SKProduct]) {
    let productsByIdentifier = products.reduce(into: [:]) { resultDict, product in
      resultDict[product.productIdentifier] = product
    }

    cachedProductsByIdentifier = cachedProductsByIdentifier.merging(productsByIdentifier)
  }

	private func cacheProduct(_ product: SKProduct) {
		queue.async {
			self.cachedProductsByIdentifier[product.productIdentifier] = product
		}
	}
}

// MARK: - SKProductsRequestDelegate
extension ProductsManager: SKProductsRequestDelegate {
	func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
		queue.async { [self] in
			Logger.debug(
        logLevel: .debug,
        scope: .productsManager,
        message: "Fetched Product",
        info: ["request": request.debugDescription],
        error: nil
      )
			guard let requestProducts = self.productsByRequests[request] else {
				Logger.debug(
          logLevel: .warn,
          scope: .productsManager,
          message: "Requested Products Not Found",
          info: ["request": request.debugDescription],
          error: nil
        )
				return
			}
			guard let completionBlocks = self.completionHandlers[requestProducts] else {
				Logger.debug(
          logLevel: .error,
          scope: .productsManager,
          message: "Completion Handler Not Found",
          info: ["products": requestProducts, "request": request.debugDescription],
          error: nil
        )
				return
			}

			self.completionHandlers.removeValue(forKey: requestProducts)
			self.productsByRequests.removeValue(forKey: request)

			self.cacheProducts(response.products)

      if response.products.isEmpty,
        !requestProducts.isEmpty {
        Logger.debug(
          logLevel: .error,
          scope: .productsManager,
          message: "No products retrieved. Visit https://superwall.com/l/no-products to diagnose.",
          info: ["product_ids": requestProducts.description]
        )
      }

			for completion in completionBlocks {
        DispatchQueue.main.async {
          completion(.success(Set(response.products)))
        }
			}
		}
	}

	func requestDidFinish(_ request: SKRequest) {
		Logger.debug(
      logLevel: .debug,
      scope: .productsManager,
      message: "Request Complete",
      info: ["request": request.debugDescription],
      error: nil
    )
		request.cancel()
	}

	func request(_ request: SKRequest, didFailWithError error: Error) {
		queue.async { [self] in
			Logger.debug(
        logLevel: .error,
        scope: .productsManager,
        message: "Request Failed",
        info: ["request": request.debugDescription],
        error: error
      )
			guard let products = productsByRequests[request] else {
				Logger.debug(
          logLevel: .error,
          scope: .productsManager,
          message: "Requested Products Not Found.",
          info: ["request": request.debugDescription],
          error: error
        )
				return
			}
			guard let completionBlocks = completionHandlers[products] else {
				Logger.debug(
          logLevel: .error,
          scope: .productsManager,
          message: "Callback Not Found for Failed Request",
          info: ["request": request.debugDescription],
          error: error
        )
				return
			}

			completionHandlers.removeValue(forKey: products)
      productsByRequests.removeValue(forKey: request)
			for completion in completionBlocks {
        DispatchQueue.main.async {
          completion(.failure(error))
        }
			}
		}
		request.cancel()
	}
}

// MARK: - Sendable
// @unchecked because:
// - It has mutable state, but it's made thread-safe through `queue`.
// - It's non-final, but only because we mock it.
extension ProductsManager: @unchecked Sendable {}
