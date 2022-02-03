//
//  File.swift
//  
//
//  Created by brian on 7/27/21.
//

import Foundation

/*
 
 Events conform to a descriminiating union
 
{
    "event_name": "close",
},

{
    "event_name": "open_url",
    "url": "https://exmaple.com"
}
 
 
*/

internal struct WrappedPaywallEvents: Decodable {
    public var version: Int = 1
    public var payload: PayloadEvents
}

internal struct PayloadEvents: Decodable {
    var events: Array<PaywallEvent>
}



internal enum PaywallEvent: Decodable {
    case onReady
	case templateParamsAndUserAttributes
    case close
    case restore
    case openUrl(url: URL)
    case openDeepLink(url: URL)
    case purchase(product: ProductType)
    case custom(data: String)
}

extension PaywallEvent {

    private enum EventNames: String, Decodable {
        case onReady = "ping"
        case close
        case restore
        case openUrl = "open_url"
        case openDeepLink
        case purchase
        case custom
    }
    
    // Everyone write to eventName, other may use the remaining keys
    private enum CodingKeys: String, CodingKey {
        case eventName
        case product
        case url
        case link
        case data
    }

    enum PaywallEventError: Error {
        case decoding(String)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let eventName = try? values.decode(EventNames.self, forKey: .eventName) {
            switch (eventName) {
            case .close:
                self = .close
                return
            case .onReady:
                self = .onReady
                return
            case .purchase:
                if let product = try? values.decode(ProductType.self, forKey: .product){
                    self = .purchase(product: product)
                    return
                }
            case .restore:
                self = .restore
                return
            case .openUrl:
                if let urlString = try? values.decode(String.self, forKey: .url), let url = URL(string: urlString) {
                    self = .openUrl(url: url)
                    return
                }
            case .openDeepLink:
                if let urlString = try? values.decode(String.self, forKey: .link), let url = URL(string: urlString) {
                    self = .openDeepLink(url: url)
                    return
                }
            case .custom:
                if let dataString = try? values.decode(String.self, forKey: .data) {
                    self = .custom(data: dataString)
                    return
                }
            }
            
        }
        throw PaywallEventError.decoding("Whoops! \(dump(values))")
    }
}

internal enum PaywallPresentationResult {
    case closed
    case initiatePurchase(productId: String)
    case initiateRestore
    case custom(string: String)
    case openedURL(url: URL)
    case openedDeepLink(url: URL)
}
