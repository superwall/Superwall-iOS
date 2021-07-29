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
    public var version: Int = 1;
    public var payload: PayloadEvents;
};

public struct PayloadEvents: Decodable {
    var events: Array<PaywallEvent>;
};

public struct InitiatePurchaseParameters: Codable {
    var productId: String
};


public enum PaywallEvent: Decodable {
    case Ping
    case Close
    case Restore
    case OpenURL(url: URL)
    case OpenDeepLink(url: URL)
    case InitiatePurchase(purchase: InitiatePurchaseParameters)
};

extension PaywallEvent {

    private enum EventNames: String, Decodable {
        case Ping = "ping"
        case Close = "close"
        case Restore = "restore"
        case OpenURL = "open_url"
        case OpenDeepLink = "open_deep_link"
        case InitiatePurchase = "initiate_purchase"
    };
    
    // Everyone write to eventName, other may use the remaining keys
    private enum CodingKeys: String, CodingKey {
        case eventName = "event_name"
        case Purchase = "purchase"
        case URL = "url"
        case Link = "link"
    }

    enum PaywallEventError: Error {
        case decoding(String)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let eventName = try? values.decode(EventNames.self, forKey: .eventName) {
            switch (eventName) {
            case .Close:
                self = .Close
                return;
            case .Ping:
                self = .Ping
                return;
            case .InitiatePurchase:
                if let purchase = try? values.decode(InitiatePurchaseParameters.self, forKey: .Purchase){
                    self = .InitiatePurchase(purchase: purchase)
                    return;
                }
            case .Restore:
                self = .Restore
                return;
            case .OpenURL:
                if let urlString = try? values.decode(String.self, forKey: .URL), let url = URL(string: urlString) {
                    self = .OpenURL(url: url)
                    return;
                }
            case .OpenDeepLink:
                if let urlString = try? values.decode(String.self, forKey: .Link), let url = URL(string: urlString) {
                    self = .OpenDeepLink(url: url)
                    return;
                }
            }
        }
        throw PaywallEventError.decoding("Whoops! \(dump(values))")
    }
}

public enum PaywallPresentationResult {
    case Closed
    case InitiatePurchase(productId: String)
    case InitiateResotre
    case OpenedURL(url: URL)
    case OpenedDeepLink(url: URL)
}
