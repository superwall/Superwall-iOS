//
//  File.swift
//  
//
//  Created by Jake Mor on 12/26/21.
//

import Foundation
import StoreKit

// Config

internal struct ProductConfig: Decodable {
	var identifier: String
}

internal struct PaywallConfig: Decodable {
	var identifier: String
	var products: [ProductConfig]
}

internal struct ConfigResponse: Decodable {
	var triggers: [Trigger]
	var paywalls: [PaywallConfig]
	var logLevel: Int
	var postback: PostbackRequest
	
	func cache() {
		for paywall in paywalls {
			StoreKitManager.shared.get(productsWithIds: paywall.products.map { $0.identifier }, completion: nil)
			PaywallManager.shared.viewController(identifier: paywall.identifier, event: nil, cached: true, completion: nil)
		}
		
		if Paywall.shouldPreloadTriggers {
			let eventNames: Set<String> = Set(triggers.map { $0.eventName })
			for e in eventNames {
				let event = EventData(id: UUID().uuidString, name: e, parameters: JSON(["caching": true]), createdAt: Date().isoString)
				PaywallResponseManager.shared.getResponse(event: event, completion: {_, _ in})
			}
		}
	}
	
	func executePostback() {
		
		DispatchQueue.main.asyncAfter(deadline: .now() + postback.postbackDelay, execute: {
			StoreKitManager.shared.get(productsWithIds: postback.productsToPostBack.map { $0.identifier }) { productsById in
				let products = productsById.values.map(PostbackProduct.init)
				let postback = Postback(products: products)
				Network.shared.postback(postback: postback) { _ in
					
				}
			}
		})

	}
}

// Triggers

internal struct Trigger: Decodable {
	var eventName: String
}

// Postback

internal struct PostBackResponse: Codable {
	var status: String
}

internal struct PostbackProductIdentifier: Codable {
	var identifier: String
	var platform: String
	
	var isiOS: Bool {
		return platform.lowercased() == "ios"
	}
}

internal struct PostbackRequest: Codable {
	var products: [PostbackProductIdentifier]
	var delay: Int?
	
	var postbackDelay: Double {
		if let delay = delay {
			return Double(delay) / 1000
		} else {
			return Double.random(in: 2.0 ..< 10.0)
		}
	}
	
	var productsToPostBack: [PostbackProductIdentifier] {
		return products.filter { $0.isiOS }
	}
}


internal struct Postback: Codable {
	var products: [PostbackProduct]
}

internal struct PostbackProduct: Codable {
	var identifier: String
	var productVariables: JSON
	var product: SWProduct
	
	init(product: SKProduct) {
		self.identifier = product.productIdentifier
		self.productVariables = product.productVariables
		self.product = SWProduct(product: product)
	}
}
