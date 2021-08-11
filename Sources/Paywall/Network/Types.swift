//
//  File.swift
//  
//
//  Created by Jake Mor on 8/11/21.
//

import UIKit
import Foundation
import StoreKit

struct EmptyResponse: Decodable {}

// MARK: Paywall

struct PaywallRequest: Codable {
    var appUserId: String
}

struct PaywallResponse: Decodable {
    var url: String
    
    var presentationStyle: PaywallPresentationStyle = .sheet
    var backgroundColorHex: String? = nil
    
    var substitutions: [Substitution]
    var products: [Product]
    var variables: [Variables]? = []
    
    var paywallBackgroundColor: UIColor {
        
        if let s = backgroundColorHex {
            return UIColor(hexString: s)
        }
        
        return UIColor.darkGray
    }
    
    var productIds: [String] {
        return products.map { $0.productId }
    }

    var templateSubstitutions: TemplateSubstitutions {
        let subs = self.substitutions.reduce([String: String]()) { (dict, sub) -> [String: String] in
            var dict = dict
            dict[sub.key] = sub.value
            return dict
        }
    
        return TemplateSubstitutions(event_name: "template_substitutions", substitutions: subs)
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
    
    var templateProducts: TemplateProducts {
        return TemplateProducts(event_name: "products", products: products)
    }
    
    var templateEventsBase64String: String {

        let encodedStrings = [encodedEventString(templateSubstitutions), encodedEventString(templateProducts), encodedEventString(templateVariables)]
        let string = "[" + encodedStrings.joined(separator: ",") + "]"
        
        let utf8str = string.data(using: .utf8)
        return utf8str?.base64EncodedString() ?? ""
    }
    
    private func encodedEventString<T: Codable>(_ input: T) -> String {
        let data = try? JSONEncoder().encode(input)
        return data != nil ? String(data: data!, encoding: .utf8) ?? "{}" : "{}"
    
    }
    
}

struct Substitution: Decodable {
    var key: String
    var value: String
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

struct TemplateSubstitutions: Codable {
    var event_name: String
    var substitutions: [String: String]
}

struct TemplateVariables: Codable {
    var event_name: String
    var variables: [String: [String: String]]
}

struct TemplateProducts: Codable {
    var event_name: String
    var products: [Product]
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
