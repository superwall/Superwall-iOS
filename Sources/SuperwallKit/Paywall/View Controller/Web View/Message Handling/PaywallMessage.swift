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
  "url": "https://example.com",
  "browser_type": "payment_sheet" // optional
}

*/

struct WrappedPaywallMessages: Decodable {
  var version: Int = 1
  var payload: PayloadMessages
}

struct PayloadMessages: Decodable {
  var messages: [PaywallMessage]

  private enum CodingKeys: String, CodingKey {
    case messages = "events"
  }
}

enum ReviewType: String, Decodable {
  case inApp = "in-app"
  case external
}

enum PaywallMessage: Decodable, Equatable {
  case onReady(paywallJsVersion: String)
	case templateParamsAndUserAttributes
  case close
  case restore
  case openUrl(_ url: URL)
  case openUrlInSafari(_ url: URL)
  case openPaymentSheet(_ url: URL)
  case openDeepLink(url: URL)
  case purchase(productId: String)
  case custom(data: String)
  case customPlacement(name: String, params: JSON)
  case requestStoreReview(ReviewType)

  // All cases below here are sent from device to paywall
  case paywallClose
  case paywallOpen

  case restoreStart
  case restoreFail(String)
  case restoreComplete

  case transactionRestore
  case transactionStart
  case transactionComplete
  case transactionFail
  case transactionAbandon
  case transactionTimeout

  private enum MessageTypes: String, Decodable {
    case onReady = "ping"
    case close
    case restore
    case openUrl = "open_url"
    case openUrlInSafari = "open_url_external"
    case openDeepLink = "open_deep_link"
    case purchase
    case custom
    case customPlacement = "custom_placement"
    case requestStoreReview = "request_store_review"
  }

  // Everyone write to eventName, other may use the remaining keys
  private enum CodingKeys: String, CodingKey {
    case messageType = "eventName"
    case productId = "productIdentifier"
    case url
    case link
    case data
    case version
    case name
    case params
    case reviewType
    case browserType
  }

  enum PaywallMessageError: Error {
    case decoding(String)
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    if let messageType = try? values.decode(MessageTypes.self, forKey: .messageType) {
      switch messageType {
      case .close:
        self = .close
        return
      case .onReady:
        let version = try values.decode(String.self, forKey: .version)
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
          let browserType = try? values.decode(String.self, forKey: .browserType)
          self = browserType == "payment_sheet" ? .openPaymentSheet(url) : .openUrl(url)
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
      case .customPlacement:
        if let name = try? values.decode(String.self, forKey: .name),
          let params = try? values.decode(JSON.self, forKey: .params) {
          self = .customPlacement(name: name, params: params)
          return
        }
      case .requestStoreReview:
        if let reviewType = try? values.decode(ReviewType.self, forKey: .reviewType) {
          self = .requestStoreReview(reviewType)
          return
        }
      }
    }

    throw PaywallMessageError.decoding("Whoops! \(dump(values))")
  }
}
