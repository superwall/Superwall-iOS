//
//  File.swift
//  
//
//  Created by Jake Mor on 8/11/21.
//

import Foundation
import StoreKit
import TPInAppReceipt

class StoreKitManager: NSObject {
    // Keep a strong reference to the product request.
    
    internal static var shared = StoreKitManager()
    
    var networkWorkers = [String: StoreKitNetworking]() // strong reference so they don't get dealocated
    
    
    func getVariables(forResponse response: PaywallResponse, completion: @escaping ([Variables]) -> ()) {
        get(productsWithIds: response.productIds) { productsById in
            var variables = [Variables]()
            
            for p in response.products {
                if let appleProduct = productsById[p.productId] {
                    variables.append(Variables(key: p.product.rawValue, value: appleProduct.eventData))
                }
            }
            
            completion(variables)
        }
    }
    
    func get(productsWithIds: [String], completion: @escaping ([String: SKProduct]) -> ()) {
        
        Logger.superwallDebug("Begining to fetch products from ASC ...")
        
		let id = UUID().uuidString
        networkWorkers[id] = StoreKitNetworking()

		networkWorkers[id]?.get(productsWithIds: productsWithIds) {
        
            
            
            var output = [String: SKProduct]()
			guard let network = self.networkWorkers[id] else {
				Logger.superwallDebug("Lost reference to StoreKitNetworker")
				return
			}
            for p in network.products {
                output[p.productIdentifier] = p
            }
            
            Logger.superwallDebug("Done fetching products from ASC")
            completion(output)
            self.networkWorkers[network.id] = nil
        }
        
    }
    
    
}


class StoreKitNetworking: NSObject, SKProductsRequestDelegate {
    
	var id = ""
    var request: SKProductsRequest!
    var didLoadProducts = false
    
    var onLoadProductsComplete: (() -> ())? = nil

    func get(productsWithIds: [String], completion: @escaping () -> ()) {
        onLoadProductsComplete = completion
        didLoadProducts = false
        
        let productIdentifiers = Set(productsWithIds)
        request = SKProductsRequest(productIdentifiers: productIdentifiers)
        request.delegate = self
        request.start()
        
        Logger.superwallDebug("Fetching products began ... ")
        
    }

    var products = [SKProduct]()
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        didLoadProducts = true
        
        Logger.superwallDebug("Fetching products complete ... ")
        
        
        
        if !response.products.isEmpty {
           products = response.products
        }

        onLoadProductsComplete!()
        
        for invalidId in response.invalidProductIdentifiers {
            Logger.superwallDebug("Invalid product identifier: \(invalidId) Did you set the correct SKProduct id in the Superwall web dashboard?")
        }
    }
	
	func requestDidFinish(_ request: SKRequest) {
		Logger.superwallDebug("[StoreKitNetworking] requestDidFinish")
	}
	
	func request(_ request: SKRequest, didFailWithError error: Error) {
		Logger.superwallDebug("[StoreKitNetworking] didFailWithError Unable to reach App Store Connect", error)
	}
    
    
}
