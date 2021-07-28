//
//  File.swift
//  
//
//  Created by brian on 7/27/21.
//

import Foundation

internal struct WrappedPaywallEvent {
    public var version: Int = 1;
    public var event: PaywallEvent;
};

/*
 
 Events conform to a descriminiating union
 
{
    "event_name": "close",
}
 
{
    "event_name": "initiate_purchase",
    "purchase": {
        "purchaseId": "abcdef"
    },
}
 
 
*/

public struct InitiatePurchaseParameters: Codable {
    var productId: String
};


public enum PaywallEvent: Codable {
    case Ping
    case Close
    case InitiatePurchase(purchase: InitiatePurchaseParameters)
};

extension PaywallEvent {

    private enum EventNames: String, Decodable {
        case Ping = "ping"
        case Close = "close"
        case InitiatePurchase = "initiate_purchase"
    };
    
    // Everyone write to eventName, other may use the remaining keys
    private enum CodingKeys: String, CodingKey {
        case eventName = "event_name"
        case Purchase = "purchase"
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
            }
        }
        throw PaywallEventError.decoding("Whoops! \(dump(values))")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .Close:
            try container.encode("close", forKey: .eventName)
        case .InitiatePurchase(purchase: let purchase):
            try container.encode("initiate_purchase", forKey: .eventName)
            try container.encode(purchase, forKey: .Purchase)
        case .Ping:
            try container.encode("ping", forKey: .eventName)
        }
    }
}


public enum PaywallPresentationResult {
    case Closed
    case InitiatePurchase(productId: String)
    case Link(url: URL)
}
