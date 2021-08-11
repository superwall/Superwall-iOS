//
//  File.swift
//  
//
//  Created by Jake Mor on 8/11/21.
//

import Foundation
import StoreKit

class StoreKitManager: NSObject {
    // Keep a strong reference to the product request.
    
    internal static var shared = StoreKitManager()
    
    var networkWorkers = [String: StoreKitNetworking]() // strong reference so they don't get dealocated
    
    func get(productsWithIds: [String], completion: @escaping ([String: SKProduct]) -> ()) {
        
        Logger.superwallDebug("Begining to fetch products from ASC ...")
        
        let network = StoreKitNetworking()
        networkWorkers[network.id] = network
        
        network.get(productsWithIds: productsWithIds) {
        
            
            
            var output = [String: SKProduct]()
            
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
    
    var id = UUID().uuidString
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
    
    
}
