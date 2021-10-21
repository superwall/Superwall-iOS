//
//  File.swift
//  
//
//  Created by Jake Mor on 8/11/21.
//

import UIKit
import Foundation
import StoreKit
import CloudKit

internal struct EmptyResponse: Decodable {}

// MARK: Paywall

internal struct PaywallRequest: Codable {
    var appUserId: String
}

internal struct PaywallFromEventRequest: Codable {
	var appUserId: String
	var event: EventData? = nil
}

internal struct PaywallsResponse: Decodable {
    var paywalls: [PaywallResponse]
}

/// `PaywallInfo` is the primary class used to distinguish one paywall from another. Used primarily in `Paywall.present(onPresent:onDismiss)`'s completion handlers.
public class PaywallInfo: NSObject {
	
	/// Superwall's internal identifier for this paywall.
	var id: String
	
	/// The identifier set for this paywall in Superwall's web dashboard.
	var identifier: String
	
	/// The name set for this paywall in Superwall's web dashboard.
	var name: String
	var slug: String
	
	/// The URL where this paywall is hosted.
	var url: URL? = nil
	
	/// An array of product IDs that this paywall is displaying in `[Primary, Secondary, Tertiary]` order.
	var productIds: [String]
	
	init(id: String, identifier: String, name: String, slug: String, url: URL?, productIds: [String]) {
		self.id = id
		self.identifier = identifier
		self.name = name
		self.slug = slug
		self.url = url
		self.productIds = productIds
	}
}

internal struct PaywallResponse: Decodable {
    var id: String? = nil
    var name: String? = nil
    var slug: String? = nil
	var identifier: String? = nil
    var url: String
    var paywalljsEvent: String
    
    var presentationStyle: PaywallPresentationStyle = .sheet
    var backgroundColorHex: String? = nil
    
    var products: [Product]
    var variables: [Variables]? = []
    
    var idNonOptional: String {
        return id ?? ""
    }
	
	var paywallInfo: PaywallInfo {
		return PaywallInfo(id: id ?? "unknown", identifier: identifier ?? "unknown", name: name ?? "unknown", slug: slug ?? "unknown", url: URL(string: url), productIds: productIds)
	}
    
    var paywallBackgroundColor: UIColor {
        
        if let s = backgroundColorHex {
            return UIColor(hexString: s)
        }
        
        return UIColor.darkGray
    }
    
    var productIds: [String] {
        return products.map { $0.productId }
    }
    
    var templateVariables: TemplateVariables {
        let variables = variables ?? []
        let vars = variables.reduce([String: [String:String]]()) { (dict, variable) -> [String: [String:String]] in
            var dict = dict
            dict[variable.key] = variable.value
            return dict
        }
        
        return TemplateVariables(event_name: "template_variables", variables: vars)
    }
    
    var isFreeTrialAvailable: Bool? = false
    
    var _isFreeTrialAvailable: Bool {
        return isFreeTrialAvailable ?? false
    }
    
    var templateSubstitutionsPrefix: TemplateSubstitutionsPrefix {
        // TODO: Jake decide if we should send `freeTrial` or `null`
        return  TemplateSubstitutionsPrefix(event_name: "template_substitutions_prefix", prefix: _isFreeTrialAvailable ? "freeTrial" : nil)
    }

    var templateProducts: TemplateProducts {
        return TemplateProducts(event_name: "products", products: products)
    }
    
    var templateDevice: TemplateDevice {
        let aliases: [String]
        if let alias = Store.shared.aliasId {
            aliases = [alias]
        } else {
            aliases = []
        }

        return TemplateDevice(publicApiKey: Store.shared.apiKey ?? "", platform: "iOS", appUserId: Store.shared.appUserId ?? "", aliases: aliases, vendorId: DeviceHelper.shared.vendorId, appVersion: DeviceHelper.shared.appVersion, osVersion: DeviceHelper.shared.osVersion, deviceModel: DeviceHelper.shared.model, deviceLocale: DeviceHelper.shared.locale, deviceLanguageCode: DeviceHelper.shared.languageCode, deviceCurrencyCode: DeviceHelper.shared.currencyCode, deviceCurrencySymbol: DeviceHelper.shared.currencySymbol)
    }
    
    var templateEventsBase64String: String {
		let encodedStrings = [encodedEventString(templateDevice), encodedEventString(templateProducts), encodedEventString(templateVariables), encodedEventString(templateSubstitutionsPrefix)]
		let string = "[" + encodedStrings.joined(separator: ",") + "]"

		let utf8str = string.data(using: .utf8)
		return utf8str?.base64EncodedString() ?? ""
	}
	
	internal func equals(_ r: PaywallResponse) -> Bool {
		let sameIdentity = id == r.id && identifier == r.identifier && name == r.name && slug == r.slug && identifier == r.identifier && url == r.url && paywalljsEvent == r.paywalljsEvent && presentationStyle == r.presentationStyle && backgroundColorHex == r.backgroundColorHex
		
		let sameProducts = r.productIds == productIds
		
		return sameIdentity && sameProducts
	}
    
    private func encodedEventString<T: Codable>(_ input: T) -> String {
        let data = try? JSONEncoder().encode(input)
        return data != nil ? String(data: data!, encoding: .utf8) ?? "{}" : "{}"
    }
}

internal struct Variables: Decodable {
    var key: String
    var value: [String: String]
}

internal enum PaywallPresentationStyle: String, Decodable {
    case sheet = "SHEET"
    case modal = "MODAL"
    case fullscreen = "FULLSCREEN"
}

internal struct Product: Codable {
    var product: ProductType
    var productId: String
}


internal  enum ProductType: String, Codable {
    case primary
    case secondary
    case tertiary
}

internal struct TemplateVariables: Codable {
    var event_name: String
    var variables: [String: [String: String]]
}

internal struct TemplateSubstitutionsPrefix: Codable {
    var event_name: String
    // Right now can be `null` or `freeTrial`
    var prefix: String?
}

internal struct TemplateProducts: Codable {
    var event_name: String
    var products: [Product]
}

internal struct TemplateDevice: Codable {
    var publicApiKey: String
    var platform: String
    var appUserId: String
    var aliases: [String]
    var vendorId: String
    var appVersion: String
    var osVersion: String
    var deviceModel: String
    var deviceLocale: String
    var deviceLanguageCode: String
    var deviceCurrencyCode: String
    var deviceCurrencySymbol: String
}

// Mark - Events
internal struct EventsRequest: Codable {
    var events: [JSON]
}

internal struct EventsResponse: Codable {
    var status: String
}

internal struct EventData: Codable {
	var id: String
	var name: String
	var parameters: JSON
	var createdAt: String
	
	var jsonData: JSON {
		return [
			"event_id": JSON(id),
			"event_name": JSON(name),
			"parameters": parameters,
			"created_at": JSON(createdAt),
		]
	}
}

// Config

internal struct ConfigResponse: Decodable {
	var triggers: [Trigger]
	var productIdentifierGroups: [[String]]
}

// Triggers

internal struct Trigger: Decodable {
	var eventName: String
}
