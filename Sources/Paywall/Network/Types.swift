//
//  File.swift
//  
//
//  Created by Jake Mor on 8/11/21.
//

import UIKit
import Foundation

struct EmptyResponse: Decodable {}

// MARK: Paywall

struct PaywallRequest: Codable {
    var appUserId: String
}

struct PaywallResponse: Decodable {
    var url: String
    var substitutions: [Substitution]
    var presentationStyle: PaywallPresentationStyle = .sheet
    var backgroundColorHex: String? = nil
    var products: [Product]
    var paywallBackgroundColor: UIColor {
        
        if let s = backgroundColorHex {
            return UIColor(hexString: s)
        }
        
        return UIColor.darkGray
    }
    
}

struct Substitution: Decodable {
    var key: String
    var value: String
}

public enum PaywallPresentationStyle: String, Decodable {
    case sheet = "SHEET"
    case modal = "MODAL"
    case fullscreen = "FULLSCREEN"
}

struct Product: Codable {
    var product: ProductType
    var productId: String
    var price: String? = "$89.99"
}


public enum ProductType: String, Codable {
    case primary = "primary"
    case secondary = "secondary"
    case tertiary = "tertiary"
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
