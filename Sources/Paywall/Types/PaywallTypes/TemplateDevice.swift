//
//  TemplateDevice.swift
//  Paywall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import Foundation

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

  func toDictionary() -> [String: Any] {
    guard let data = try? JSONEncoder().encode(self) else {
      return [:]
    }
    let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
    if let dictionary = jsonObject.flatMap({ $0 as? [String: Any] }) {
      return dictionary
    } else {
      return [:]
    }
  }
}
