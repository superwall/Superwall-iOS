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
  "url": "https://example.com"
}

*/

struct WrappedPaywallEvents: Decodable {
  var version: Int = 1
  var payload: PayloadEvents
}

struct PayloadEvents: Decodable {
  var events: [PaywallEvent]
}

enum PaywallEvent: Decodable {
  case onReady(paywallJsVersion: String?)
	case templateParamsAndUserAttributes
  case close
  case restore
  case openUrl(_ url: URL)
  case openUrlInSafari(_ url: URL)
  case openDeepLink(url: URL)
  case purchase(productId: String)
  case custom(data: String)
}

extension PaywallEvent {
  private enum EventNames: String, Decodable {
    case onReady = "ping"
    case close
    case restore
    case openUrl = "open_url"
    case openUrlInSafari = "open_url_external"
    case openDeepLink = "open_deep_link"
    case purchase
    case custom
  }

  // Everyone write to eventName, other may use the remaining keys
  private enum CodingKeys: String, CodingKey {
    case eventName
    case productId = "productIdentifier"
    case url
    case link
    case data
    case version
  }

  enum PaywallEventError: Error {
    case decoding(String)
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    if let eventName = try? values.decode(EventNames.self, forKey: .eventName) {
      switch eventName {
      case .close:
        self = .close
        return
      case .onReady:
        let version = try? values.decode(String.self, forKey: .version)
        self = .onReady(paywallJsVersion: version)
        return
      case .purchase:
        if let productId = try? values.decode(String.self, forKey: .productId) {
          self = .purchase(productId: productId)
          return
        }
      case .restore:
        self = .restore
        return
      case .openUrl:
        if let urlString = try? values.decode(String.self, forKey: .url),
          let url = URL(string: urlString) {
          self = .openUrl(url)
          return
        }
      case .openUrlInSafari:
        if let urlString = try? values.decode(String.self, forKey: .url),
          let url = URL(string: urlString) {
          self = .openUrlInSafari(url)
          return
        }
      case .openDeepLink:
        if let urlString = try? values.decode(String.self, forKey: .link),
          let url = URL(string: urlString) {
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
