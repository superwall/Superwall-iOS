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

struct EmptyResponse: Decodable {}

// MARK: Paywall

struct PaywallRequest: Codable {
    var appUserId: String
}

struct PaywallResponse: Decodable {
    var id: String? = nil
    var url: String
    var paywalljsEvent: String
    
    var presentationStyle: PaywallPresentationStyle = .sheet
    var backgroundColorHex: String? = nil
    
    var products: [Product]
    var variables: [Variables]? = []
    
    var idNonOptional: String {
        return id ?? ""
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
    
    private func encodedEventString<T: Codable>(_ input: T) -> String {
        let data = try? JSONEncoder().encode(input)
        return data != nil ? String(data: data!, encoding: .utf8) ?? "{}" : "{}"
    }
}

struct Variables: Decodable {
    var key: String
    var value: [String: String]
}

public enum PaywallPresentationStyle: String, Decodable {
    case sheet = "SHEET"
    case modal = "MODAL"
    case fullscreen = "FULLSCREEN"
}

struct Product: Codable {
    var product: ProductType
    var productId: String
}


public enum ProductType: String, Codable {
    case primary
    case secondary
    case tertiary
}

struct TemplateVariables: Codable {
    var event_name: String
    var variables: [String: [String: String]]
}

struct TemplateSubstitutionsPrefix: Codable {
    var event_name: String
    // Right now can be `null` or `freeTrial`
    var prefix: String?
}

struct TemplateProducts: Codable {
    var event_name: String
    var products: [Product]
}

struct TemplateDevice: Codable {
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

// TODO: UserProperties


struct UserPropertiesRequest: Codable {
    var apnsToken: String?
    var fcmToken: String?
    var email: String?
    var phoneCountryCode: String?
    var phone: String?
    var firstName: String?
    var lastName: String?
}


// Mark - Events
struct EventsRequest: Codable {
    var events: [JSON]
}

struct EventsResponse: Codable {
    var status: String
}

// Mark - Identify

struct IdentifyRequest: Codable {
    var parameters: JSON
    var created_at: JSON
}

struct IdentifyResponse: Codable {
    var status: String
}

