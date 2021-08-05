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

public struct PayloadEvents: Decodable {
    var events: Array<PaywallEvent>
}

public struct InitiatePurchaseParameters: Codable {
    var productId: String
}


public enum PaywallEvent: Decodable {
    case ping
    case close
    case restore
    case openURL(url: URL)
    case openDeepLink(url: URL)
    case initiatePurchase(purchase: InitiatePurchaseParameters)
}

extension PaywallEvent {

    private enum EventNames: String, Decodable {
        case ping = "ping"
        case close = "close"
        case restore = "restore"
        case openURL = "open_url"
        case openDeepLink = "open_deep_link"
        case initiatePurchase = "initiate_purchase"
    }
    
    // Everyone write to eventName, other may use the remaining keys
    private enum CodingKeys: String, CodingKey {
        case eventName = "event_name"
        case purchase = "purchase"
        case url = "url"
        case link = "link"
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
            case .ping:
                self = .ping
                return
            case .initiatePurchase:
                if let purchase = try? values.decode(InitiatePurchaseParameters.self, forKey: .purchase){
                    self = .initiatePurchase(purchase: purchase)
                    return
                }
            case .restore:
                self = .restore
                return
            case .openURL:
                if let urlString = try? values.decode(String.self, forKey: .url), let url = URL(string: urlString) {
                    self = .openURL(url: url)
                    return
                }
            case .openDeepLink:
                if let urlString = try? values.decode(String.self, forKey: .link), let url = URL(string: urlString) {
                    self = .openDeepLink(url: url)
                    return
                }
            }
        }
        throw PaywallEventError.decoding("Whoops! \(dump(values))")
    }
}

public enum PaywallPresentationResult {
    case closed
    case initiatePurchase(productId: String)
    case initiateResotre
    case openedURL(url: URL)
    case openedDeepLink(url: URL)
}
