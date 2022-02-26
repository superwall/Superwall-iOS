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


internal struct LocaleConfig: Decodable {
    var locale: String
}

internal struct LocalizationConfig: Decodable {
    var locales: [LocaleConfig]
}
internal struct ConfigResponse: Decodable {
	var triggers: [Trigger]
	var paywalls: [PaywallConfig]
	var logLevel: Int
	var postback: PostbackRequest
    var localization: LocalizationConfig
	
	func cache() {
		
		// for each paywall ...
		for paywall in paywalls {
			// cache its products
			StoreKitManager.shared.get(productsWithIds: paywall.products.map { $0.identifier }, completion: nil)
			// cache the view controller
			PaywallManager.shared.viewController(identifier: paywall.identifier, event: nil, cached: true, completion: nil)
		}
        
        // Pre-load all the paywalls from v2 triggers
        var identifiers: [String] = [];
        triggers.forEach { (trigger) in
            switch(trigger.triggerVersion) {
            case .V1:
                break;
            case .V2(let triggerV2):
                triggerV2.rules.forEach { (rule) in
                    switch(rule.variant) {
                    case .Treatment(let treatment):
                        identifiers.append(treatment.paywallIdentifier)
                    default:
                        break;
                    }
                }
            }
        }
        for identifier in Set(identifiers) {
            PaywallManager.shared.viewController(identifier: identifier, event: nil, cached: true, completion: nil)
        }
        
		// cache paywall.present(), when identifier and event is nil
		PaywallManager.shared.viewController(identifier: nil, event: nil, cached: true, completion: nil)
		
		// if we should preload trigger responses
		if Paywall.shouldPreloadTriggers {
            let eventNames: Set<String> = Set(triggers.filter({ (trigger) in
                switch(trigger.triggerVersion) {
                case .V1:
                    return true
                default:
                    return false
                }
            }).map { $0.eventName })
			for e in eventNames {
				let event = EventData(id: UUID().uuidString, name: e, parameters: JSON(["caching": true]), createdAt: Date().isoString)
				// prelaod the response for that trigger
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



//enum TriggerVersion: Decodable {
//    case V1
//    case V2
//    init(from decoder: Decoder) throws {
//       let label = try decoder.singleValueContainer().decode(String.self)
//       switch label {
//          case "V1": self = .V1
//          case "V2": self = .V2
//       default:
//           self = .V1
//           break;
//       }
//    }
//}



//internal struct Trigger: Decodable {
//	var eventName: String
//    var triggerVersion: TriggerVersion
//}

internal struct TriggerV2: Decodable {
    // Just for convience, should be captured in the "Trigger" struct
    var eventName: String
    var rules: [TriggerRule]
}

internal struct TriggerRule: Decodable {
    var experimentId: String
    var expression: String?
    var assigned: Bool
    var variant: Variant
    var variantId: String
    
    enum Keys: String, CodingKey {
        case experimentId;
        case expression;
        case assigned;
        case variant;
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: TriggerRule.Keys.self)
        experimentId = try values.decode(String.self, forKey: .experimentId)
        expression = try? values.decode(String.self, forKey: .expression)
        assigned = try values.decode(Bool.self, forKey: .assigned)
        variant = try values.decode(Variant.self, forKey: .variant)
        switch(variant) {
        case .Holdout(let holdout):
            variantId = holdout.variantId
        case .Treatment(let treatment):
            variantId = treatment.variantId
        }
    }
}

internal enum Variant: Decodable {
    case Treatment(VariantTreatment)
    case Holdout(VariantHoldout)
    
    enum Keys:  String, CodingKey {
        case variantType;
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: Variant.Keys.self)
        let variantType = try values.decode(String.self, forKey: .variantType)
       switch variantType {
       case "HOLDOUT":
           self = .Holdout(try VariantHoldout.init(from: decoder))
       case "TREATMENT":
           self = .Treatment(try VariantTreatment.init(from: decoder))
       default:
           // TODO: Handle unknowns better
           self = .Holdout(try VariantHoldout.init(from: decoder))
       }
    }
}

        
internal struct VariantTreatment: Decodable {
    var variantId: String
    var paywallIdentifier: String
}

internal struct VariantHoldout: Decodable {
    var variantId: String
}


enum TriggerVersion: Decodable {
    case V1
    case V2(TriggerV2)

    enum Keys:  String, CodingKey {
        case triggerVersion;
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: TriggerVersion.Keys.self)
        let triggerVersion = try values.decode(String.self, forKey: .triggerVersion)
        
        switch triggerVersion {
            case "V1": self = .V1
            case "V2": self = .V2(try TriggerV2.init(from: decoder))
            default:
                self = .V1
        }
    }
}


struct Trigger: Decodable {
    var eventName: String
    var triggerVersion: TriggerVersion
    
    enum Keys: String, CodingKey {
        case eventName;
        case triggerVersion;
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: Trigger.Keys.self)
        eventName = try values.decode(String.self, forKey: .eventName)
        let triggerVersionString = try values.decode(String.self, forKey: .triggerVersion)
        switch (triggerVersionString) {
        case "V2":
            triggerVersion = .V2(try TriggerV2.init(from: decoder))
                break;
        
            default:
                triggerVersion = .V1
                break;
        }
    }
}

// Confirm Assignments


internal struct ConfirmAssignments: Codable {
    var assignments: [Assignment]
}
internal struct Assignment: Codable {
    var experimentId: String
    var variantId: String
}

internal struct ConfirmAssignmentResponse: Codable {
    var status: String
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
