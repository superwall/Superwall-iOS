//
//  File.swift
//  
//
//  Created by Jake Mor on 12/26/21.
//
import Foundation
import UIKit

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
	internal let id: String
	
	/// The identifier set for this paywall in Superwall's web dashboard.
	public let identifier: String
    
    /// What experiment this paywall presentation is a party of
    public let experimentId: String?
    
    /// What variant this user saw
    public let variantId: String?
	
	/// The name set for this paywall in Superwall's web dashboard.
	public let name: String
	public let slug: String
	
	/// The URL where this paywall is hosted.
	public let url: URL?
		
	/// The name of the event that triggered this Paywall. Defaults to `nil` if `triggeredByEvent` is false.
	public let presentedByEventWithName: String?
	
	/// The Superwall internal id (for debugging) of the event that triggered this Paywall. Defaults to `nil` if `triggeredByEvent` is false.
	public let presentedByEventWithId: String?
	
	/// The ISO date string (sorry) describing when the event triggered this paywall. Defaults to `nil` if `triggeredByEvent` is false.
	public let presentedByEventAt: String?
	
	/// How the paywall was presented, either 'programmatically', 'identifier', or 'event'
	public let presentedBy: String
	
	/// An array of product IDs that this paywall is displaying in `[Primary, Secondary, Tertiary]` order.
	public let productIds: [String]
	
	
	public let responseLoadStartTime: String?
	public let responseLoadCompleteTime: String?
	public let responseLoadDuration: Double?
	
	public let webViewLoadStartTime: String?
	public let webViewLoadCompleteTime: String?
	public let webViewLoadDuration: Double?
	
	public let productsLoadStartTime: String?
	public let productsLoadCompleteTime: String?
	public let productsLoadDuration: Double?

    init(
		id: String,
		identifier: String,
		name: String,
		slug: String,
		url: URL?,
		productIds: [String],
		fromEventData: EventData?,
		calledByIdentifier: Bool = false,
		responseLoadStartTime: Date?,
		responseLoadCompleteTime: Date?,
		webViewLoadStartTime: Date?,
		webViewLoadCompleteTime: Date?,
		productsLoadStartTime: Date?,
		productsLoadCompleteTime: Date?,
		variantId: String? = nil,
		experimentId: String? = nil) {
		self.id = id
		self.identifier = identifier
		self.name = name
		self.slug = slug
		self.url = url
		self.productIds = productIds
		self.presentedByEventWithName = fromEventData?.name
		self.presentedByEventAt = fromEventData?.createdAt
		self.presentedByEventWithId = fromEventData?.id.lowercased()
        self.variantId = variantId
        self.experimentId = experimentId
		
		if fromEventData != nil {
			self.presentedBy = "event"
		} else if calledByIdentifier {
			self.presentedBy = "identifier"
		} else {
			self.presentedBy = "programmatically"
		}

	
		self.responseLoadStartTime = responseLoadStartTime?.isoString ?? ""
		self.responseLoadCompleteTime = responseLoadStartTime?.isoString ?? ""
		if let s = responseLoadStartTime, let e = responseLoadCompleteTime {
			self.responseLoadDuration = e.timeIntervalSince1970 - s.timeIntervalSince1970
		} else {
			self.responseLoadDuration = nil
		}
		
		self.webViewLoadStartTime = webViewLoadStartTime?.isoString ?? ""
		self.webViewLoadCompleteTime = webViewLoadCompleteTime?.isoString ?? ""
		if let s = webViewLoadStartTime, let e = webViewLoadCompleteTime {
			self.webViewLoadDuration = e.timeIntervalSince1970 - s.timeIntervalSince1970
		} else {
			self.webViewLoadDuration = nil
		}
		
		self.productsLoadStartTime = productsLoadStartTime?.isoString ?? ""
		self.productsLoadCompleteTime = productsLoadCompleteTime?.isoString ?? ""
		if let s = productsLoadStartTime, let e = productsLoadCompleteTime {
			self.productsLoadDuration = e.timeIntervalSince1970 - s.timeIntervalSince1970
		} else {
			self.productsLoadDuration = nil
		}
		
			
	}
}

public class TriggerInfo: NSObject {
    public let experimentId: String?
    public let variantId: String?
    
    // "holdout", "no_rule_match", "present"
    public let result: String
    public let paywallIdentifier: String?
    init(result: String, experimentId: String?, variantId: String?, paywallIdentifier: String?) {
        self.result = result
        self.experimentId = experimentId
        self.variantId = variantId
        self.paywallIdentifier = paywallIdentifier
    }
}

internal struct PaywallResponse: Decodable {
	var id: String? = nil
	var name: String? = nil
	var slug: String? = nil
    
    var variantId: String? = nil
    var experimentId: String? = nil
    
	var identifier: String? = nil
	var url: String
	var paywalljsEvent: String
	
	var presentationStyle: PaywallPresentationStyle = .sheet
	var backgroundColorHex: String? = nil
	
	var products: [Product]
	var variables: [Variables]? = []
	var productVariables: [ProductVariables]? = []
	
	var idNonOptional: String {
		return id ?? ""
	}
	
//	var paywallInfo: PaywallInfo {
//
//	}
	

	var responseLoadStartTime: Date? = nil
	var responseLoadCompleteTime: Date? = nil
	
	var webViewLoadStartTime: Date? = nil
	var webViewLoadCompleteTime: Date? = nil
	
	var productsLoadStartTime: Date? = nil
	var productsLoadCompleteTime: Date? = nil
	
	func getPaywallInfo(fromEvent: EventData?, calledByIdentifier: Bool = false, includeExperiment: Bool = false) -> PaywallInfo {
		return PaywallInfo(id: id ?? "unknown",
						   identifier: identifier ?? "unknown",
						   name: name ?? "unknown",
						   slug: slug ?? "unknown",
						   url: URL(string: url),
						   productIds: productIds,
						   fromEventData: fromEvent,
						   calledByIdentifier: calledByIdentifier,
						   responseLoadStartTime: responseLoadStartTime,
						   responseLoadCompleteTime: responseLoadCompleteTime,
						   webViewLoadStartTime: webViewLoadStartTime,
						   webViewLoadCompleteTime: webViewLoadCompleteTime,
						   productsLoadStartTime: productsLoadStartTime,
						   productsLoadCompleteTime: productsLoadCompleteTime,
						   variantId: includeExperiment ? variantId : nil,
						   experimentId: includeExperiment ? experimentId : nil
		)
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
	
	
	var templateVariables: JSON {
		
		var variables: [String: Any] = [
			"user": Store.shared.userAttributes,
            "device": DeviceHelper.shared.templateDevice.dictionary ?? [String: Any]()
		]
		
		for v in self.variables ?? [Variables]() {
			variables[v.key] = v.value
		}
		
		let values: [String: Any] = [
			"event_name":"template_variables",
			"variables": variables
		]
		
		
		return JSON(values)
	}
	
	var templateProductVariables: JSON {
		var variables: [String: Any] = [:]
		
		for v in self.productVariables ?? [ProductVariables]() {
			variables[v.key] = v.value
		}
		
		let values: [String: Any] = [
			"event_name":"template_product_variables",
			"variables": variables
		]
		
		return JSON(values)
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
	
	
	func getBase64EventsString(params: JSON? = nil) -> String {
		
		var templateVariables = self.templateVariables
		
		if let params = params {
			templateVariables["variables"]["params"] = params
		} else {
			templateVariables["variables"]["params"] = JSON([String:Any]())
		}
		
        let encodedStrings = [encodedEventString(DeviceHelper.shared.templateDevice), encodedEventString(templateProducts), encodedEventString(templateSubstitutionsPrefix), encodedEventString(templateVariables), encodedEventString(templateProductVariables)]
		
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
	var value: JSON
}

internal struct ProductVariables: Decodable {
	var key: String
	var value: JSON
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
    
    func toDictionary() -> [String: Any]{
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] } as? [String : Any] ?? [:]
    }
}
