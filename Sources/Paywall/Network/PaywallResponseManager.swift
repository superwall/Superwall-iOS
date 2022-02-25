//
//  File.swift
//  
//
//  Created by Jake Mor on 10/19/21.
//

import Foundation
import StoreKit
import TPInAppReceipt

class PaywallResponseManager: NSObject {
	
	static var shared = PaywallResponseManager()

	private var cachedResponsesByIdentifier: [String: PaywallResponse] = [:]
	private let queue = DispatchQueue(label: "PaywallRequests")
	private var responsesByHash: [String: (PaywallResponse?, NSError?)] = [:]
	private var handlersByHash: [String: [(PaywallResponse?, NSError?) -> Void]] = [:]
	
	func requestHash(identifier: String? = nil, event: EventData? = nil) -> String {
		return "\((identifier ?? event?.name ?? "$called_manually"))_\(DeviceHelper.shared.locale)"
	}
	
	func getResponse(identifier: String? = nil, event: EventData? = nil, completion: @escaping (PaywallResponse?, NSError?) -> ()) {
        var experimentId: String?  = nil
        var variantId: String? = nil
        var identifier = identifier;

		// if we're requesting a response for a trigger/event that wasn't in the initial config endpoint, ignore it
		if Paywall.shared.didFetchConfig, let eventName = event?.name {
            let triggerResponse = TriggerManager.shared.handleEvent(eventName: eventName, eventData: event)
            switch(triggerResponse) {
                // Do nothing, continue with loading as expected
            case .PresentV1:
                    break;
                
            case .PresentIdentifier(let _experimentId,  let _variantId, let paywallIdentifier):
                identifier = paywallIdentifier;
                experimentId = _experimentId
                variantId = _variantId
//                Paywall.track(.paywallResponseLoadComplete(fromEvent: isFromEvent, event: event, paywallInfo: response.getPaywallInfo(fromEvent: event)))
                Paywall.track(.triggerFire(triggerInfo: TriggerInfo(result: "present", experimentId: experimentId, variantId: variantId, paywallIdentifier: identifier)))
                break;
            case .Holdout(let experimentId, let variantId):
                let userInfo: [String : Any] = [
                    "experimentId": experimentId,
                    "variantId": variantId,
                    NSLocalizedDescriptionKey :  NSLocalizedString("Trigger Holdout", value: "This user was assigned to a holdout in a trigger experiment", comment: "ExperimentId: \(experimentId) VariantId: \(variantId)") ,
                        ]
                let error = NSError(domain: "com.superwall", code: 4001, userInfo: userInfo)
                Paywall.track(.triggerFire(triggerInfo: TriggerInfo(result: "holdout", experimentId: experimentId, variantId: variantId, paywallIdentifier: nil)))
                completion(nil, error)
                return;
            
            case .NoRuleMatch:
                let userInfo: [String : Any] = [
                                NSLocalizedDescriptionKey :  NSLocalizedString("No rule match", value: "The user did not match any rules configured for this trigger", comment: "") ,
                            ]
                let error = NSError(domain: "com.superwall", code: 4000, userInfo: userInfo)
                Paywall.track(.triggerFire(triggerInfo: TriggerInfo(result: "no_rule_match", experimentId: nil, variantId: nil, paywallIdentifier: nil)))
                completion(nil, error)
                return

                
            case .UnknownEvent:
                                // create the error
                    let userInfo: [String : Any] = [
                        NSLocalizedDescriptionKey :  NSLocalizedString("Trigger Disabled", value: "There isn't a paywall configured to show in this context", comment: "") ,
                    ]
                    let error = NSError(domain: "SWTriggerDisabled", code: 404, userInfo: userInfo)
                    completion(nil, error)
                    return
                
            }
            
        
		}
		
		let hash = requestHash(identifier: identifier, event: event)
		
		// if the response exists, return it
		if let (r, e) = responsesByHash[hash], !SWDebugManager.shared.isDebuggerLaunched {
			OnMain {
                var r = r;
                r?.experimentId = experimentId
                r?.variantId = variantId
				completion(r, e)
			}
			return
		}
		
		// if the request is in progress, enque the completion handler
		if let handlers = handlersByHash[hash] {
			handlersByHash[hash] = handlers + [completion] // to execute all completion handlers
//			handlersByHash[hash] = [completion] // to only execute the last completion handler
			return
		}
		
		// if there are no requests in progress
		handlersByHash[hash] = [completion]
		
		queue.async {
			
			let isFromEvent = event != nil
	
			let responseLoadStartTime = Date()
			Paywall.track(.paywallResponseLoadStart(fromEvent: isFromEvent, event: event))
			
			// get the paywall
		
//			OnMain(after: 2.0, {
		
			Network.shared.paywall(withIdentifier: identifier, fromEvent: event) { (result) in
				self.queue.async {
					switch(result) {
						case .success(var response):
							
                            response.experimentId = experimentId
                            response.variantId = variantId
							response.responseLoadStartTime = responseLoadStartTime
							response.responseLoadCompleteTime = Date()
								
							Paywall.track(.paywallResponseLoadComplete(fromEvent: isFromEvent, event: event, paywallInfo: response.getPaywallInfo(fromEvent: event)))
							
							response.productsLoadStartTime = Date()
							
							Paywall.track(.paywallProductsLoadStart(fromEvent: isFromEvent, event: event, paywallInfo: response.getPaywallInfo(fromEvent: event)))
							
							// add its products
							StoreKitManager.shared.get(productsWithIds: response.productIds) { productsById in
								
								var variables = [Variables]()
								var productVariables = [ProductVariables]()
//								var response = response
								
								for p in response.products {
									if let appleProduct = productsById[p.productId] {
										
										variables.append(Variables(key: p.product.rawValue, value: appleProduct.eventData))
										productVariables.append(ProductVariables(key: p.product.rawValue, value: appleProduct.productVariables))
										
										if p.product == .primary {
											response.isFreeTrialAvailable = appleProduct.hasFreeTrial
											if let receipt = try? InAppReceipt.localReceipt() {
												let hasPurchased = receipt.containsPurchase(ofProductIdentifier: p.productId)
												if hasPurchased && appleProduct.hasFreeTrial {
													response.isFreeTrialAvailable = false
												}
											}
											// use the override if it is set
											if let or = Paywall.isFreeTrialAvailableOverride {
												response.isFreeTrialAvailable = or
												Paywall.isFreeTrialAvailableOverride = nil // reset it for future use
											}
										}
									}
								}
								
								response.variables = variables
								response.productVariables = productVariables
								
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
								
								response.productsLoadCompleteTime = Date()
								Paywall.track(.paywallProductsLoadComplete(fromEvent: isFromEvent, event: event, paywallInfo: response.getPaywallInfo(fromEvent: event)))
								
							}
							
								
							
								
						case .failure(let error):
						
							if let e = error as? Network.Error, e == .notFound {
								Paywall.track(.paywallResponseLoadNotFound(fromEvent: isFromEvent, event: event))
							} else {
								Paywall.track(.paywallResponseLoadFail(fromEvent: isFromEvent, event: event))
							}
						
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
				
//			})
		
		
		}
		
		
		
	}

	func getPaywallResponses(config: ConfigResponse) {

	}

}
