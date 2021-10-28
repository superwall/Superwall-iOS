//
//  File.swift
//  
//
//  Created by Jake Mor on 10/19/21.
//

import Foundation
import StoreKit

class PaywallResponseManager: NSObject {
	
	static var shared = PaywallResponseManager()

	private var cachedResponsesByIdentifier: [String: PaywallResponse] = [:]
	private let queue = DispatchQueue(label: "PaywallRequests")
	private var responsesByHash: [String: (PaywallResponse?, NSError?)] = [:]
	private var handlersByHash: [String: [(PaywallResponse?, NSError?) -> Void]] = [:]
	
	func requestHash(identifier: String? = nil, event: EventData? = nil) -> String {
		return identifier ?? event?.name ?? "$called_manually"
	}
	
	func getResponse(identifier: String? = nil, event: EventData? = nil, completion: @escaping (PaywallResponse?, NSError?) -> ()) {
		let hash = requestHash(identifier: identifier, event: event)
		
		// if the response exists, return it
		if let (r, e) = responsesByHash[hash] {
			OnMain {
				completion(r, e)
			}
			return
		}
		
		// if the request is in progress, enque the completion handler
		if let handlers = handlersByHash[hash] {
			handlersByHash[hash] = handlers + [completion] // to execute all completion handlers
//			handlersByHash[hash] = [completion] // to 
			return
		}
		
		// if there are no requests in progress
		handlersByHash[hash] = [completion]
		
		queue.async {
			
			let isFromEvent = event != nil
	
			Paywall.track(.paywallResponseLoadStart(fromEvent: isFromEvent, event: event))
			
			Network.shared.paywall(withIdentifier: identifier, fromEvent: event) { (result) in
				self.queue.async {
					switch(result){
					case .success(let response):
							
							Paywall.track(.paywallResponseLoadComplete(fromEvent: isFromEvent, event: event))
							
							// cache the response for later
							self.responsesByHash[hash] = (response, nil)
						
							// execulte all the cached handlers
							if let handlers = self.handlersByHash[hash]  {
								OnMain {
									for h in handlers {
										h(response, nil)
									}
								}
							}
							
							// reset the handler cache
							self.handlersByHash.removeValue(forKey: hash)
							
							
					case .failure(_):
							
							Paywall.track(.paywallResponseLoadFail(fromEvent: isFromEvent, event: event))
							
							// create the error
							let userInfo: [String : Any] = [
								NSLocalizedDescriptionKey :  NSLocalizedString("Not Found", value: "There isn't a paywall configured to show in this context", comment: "") ,
							]
							let error = NSError(domain: "SWPaywallNotFound", code: 404, userInfo: userInfo)
							
							// cache the response for later
//							self.responsesByHash[hash] = (nil, error)
							
							// execulte all the cached handlers
							if let handlers = self.handlersByHash[hash] {
								OnMain {
									for h in handlers {
										h(nil, error)
									}
								}
								
								// reset the handler cache
								self.handlersByHash.removeValue(forKey: hash)
							}
							
							
					}
				}

			}
		}
		
		
		
	}

	func getPaywallResponses(config: ConfigResponse) {

	}

}
