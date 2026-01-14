//
//  PostPurchaseAction.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 14/01/2026.
//

import Foundation

enum PostPurchaseUrlType: String, Equatable, Decodable {
  case inAppBrowser = "in-app-browser"
  case deepLink = "deep-link"
  case external
  case paymentSheet = "payment_sheet"
  case unknown

  init(from decoder: Decoder) throws {
    let value = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
    self = PostPurchaseUrlType(rawValue: value) ?? .unknown
  }
}

struct PostPurchaseAttribute: Equatable, Decodable {
  let key: String
  let value: String
}

enum PostPurchaseAction: Equatable, Decodable {
  case none
  case close
  case openUrl(url: URL, urlType: PostPurchaseUrlType)
  case customInApp(data: String)
  case customPlacement(name: String)
  case setAttribute(attributes: [PostPurchaseAttribute])
  case unknown

  var shouldDismissPaywall: Bool {
    if case .close = self {
      return true
    }
    return false
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case url
    case urlType
    case data
    case name
    case attributes
  }

  init(from decoder: Decoder) throws {
    guard let values = try? decoder.container(keyedBy: CodingKeys.self),
      let type = try? values.decode(String.self, forKey: .type)
    else {
      self = .unknown
      return
    }

    switch type {
    case "none":
      self = .none
    case "close":
      self = .close
    case "open-url":
      guard let urlString = try? values.decode(String.self, forKey: .url),
        let url = URL(string: urlString)
      else {
        self = .unknown
        return
      }
      let urlType = (try? values.decode(PostPurchaseUrlType.self, forKey: .urlType)) ?? .inAppBrowser
      self = .openUrl(url: url, urlType: urlType)
    case "custom-in-app":
      if let data = try? values.decode(String.self, forKey: .data) {
        self = .customInApp(data: data)
      } else {
        self = .unknown
      }
    case "custom-placement":
      if let name = try? values.decode(String.self, forKey: .name) {
        self = .customPlacement(name: name)
      } else {
        self = .unknown
      }
    case "set-attribute":
      let attributes = (try? values.decode([PostPurchaseAttribute].self, forKey: .attributes)) ?? []
      self = .setAttribute(attributes: attributes)
    default:
      self = .unknown
    }
  }

  func toPaywallMessage() -> PaywallMessage? {
    switch self {
    case .none:
      return nil
    case .close:
      return nil
    case let .openUrl(url, urlType):
      switch urlType {
      case .deepLink:
        return .openDeepLink(url: url)
      case .external:
        return .openUrlInSafari(url)
      case .paymentSheet:
        return .openPaymentSheet(url)
      case .inAppBrowser, .unknown:
        return .openUrl(url)
      }
    case let .customInApp(data):
      return .custom(data: data)
    case let .customPlacement(name):
      return .customPlacement(name: name, params: JSON([:]))
    case let .setAttribute(attributes):
      let payload = attributes.map { ["key": $0.key, "value": $0.value] }
      return .userAttributesUpdated(attributes: JSON(payload))
    case .unknown:
      return nil
    }
  }
}
