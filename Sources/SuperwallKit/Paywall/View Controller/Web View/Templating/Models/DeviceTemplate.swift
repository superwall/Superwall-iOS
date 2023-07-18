//
//  TemplateDevice.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//

import Foundation

struct DeviceTemplate: Codable {
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
  var deviceType: String
  var timezoneOffset: Int
  var radioType: String
  var interfaceStyle: String
  var isLowPowerModeEnabled: Bool
  var bundleId: String
  var appInstallDate: String
  var isMac: Bool
  var daysSinceInstall: Int
  var minutesSinceInstall: Int
  var daysSinceLastPaywallView: Int?
  var minutesSinceLastPaywallView: Int?
  var totalPaywallViews: Int
  var utcDate: String
  var localDate: String
  var utcTime: String
  var localTime: String
  var utcDateTime: String
  var localDateTime: String
  var isSandbox: String
  var subscriptionStatus: String
  var isFirstAppOpen: Bool

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
