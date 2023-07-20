//
//  File.swift
//
//  Created by Jake Mor on 8/10/21.
//
// swiftlint:disable type_body_length

import UIKit
import Foundation
import SystemConfiguration
import CoreTelephony

class DeviceHelper {
  var locale: String {
    let localeIdentifier = factory.makeLocaleIdentifier()
    return localeIdentifier ?? Locale.autoupdatingCurrent.identifier
  }
  let appInstalledAtString: String

  private let reachability: SCNetworkReachability?
  var reachabilityFlags: SCNetworkReachabilityFlags? {
    guard let reachability = reachability else {
      return nil
    }
    var flags = SCNetworkReachabilityFlags()
    SCNetworkReachabilityGetFlags(reachability, &flags)

    return flags
  }

  var appVersion: String {
    Bundle.main.releaseVersionNumber ?? ""
  }

  let osVersion: String = {
    let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
    return String(
      format: "%ld.%ld.%ld",
      arguments: [systemVersion.majorVersion, systemVersion.minorVersion, systemVersion.patchVersion]
    )
  }()

  let isMac: Bool = {
    var output = false
    if #available(iOS 14.0, *) {
      output = ProcessInfo.processInfo.isiOSAppOnMac
    }
    return output
  }()

  let model: String = {
    UIDevice.modelName
  }()

  let vendorId: String = {
    UIDevice.current.identifierForVendor?.uuidString ?? ""
  }()

  var languageCode: String {
    Locale.autoupdatingCurrent.languageCode ?? ""
  }

  var currencyCode: String {
    Locale.autoupdatingCurrent.currencyCode ?? ""
  }

  var currencySymbol: String {
    Locale.autoupdatingCurrent.currencySymbol ?? ""
  }

  var secondsFromGMT: String {
    "\(Int(TimeZone.current.secondsFromGMT()))"
  }

  var isFirstAppOpen: Bool {
    return !storage.didTrackFirstSession
  }

  var radioType: String {
    guard let flags = reachabilityFlags else {
      return "No Internet"
    }

    let isReachable = flags.contains(.reachable)
    let isWWAN = flags.contains(.isWWAN)

    if isReachable {
      if isWWAN {
        return "Cellular"
      } else {
        return "Wifi"
      }
    } else {
      return "No Internet"
    }
  }

  var interfaceStyle: String {
    let style = UIScreen.main.traitCollection.userInterfaceStyle
    switch style {
    case .unspecified:
      return "Unspecified"
    case .light:
      return "Light"
    case .dark:
      return "Dark"
    default:
      return "Unknown"
    }
	}

  var isLowPowerModeEnabled: String {
    return ProcessInfo.processInfo.isLowPowerModeEnabled ? "true" : "false"
  }

  let bundleId: String = {
    return Bundle.main.bundleIdentifier ?? ""
  }()

  /// Returns true if built with the debug flag, or using TestFlight.
  let isSandbox: String = {
    #if DEBUG
      return "true"
    #else

    guard let url = Bundle.main.appStoreReceiptURL else {
      return "false"
    }

    return "\(url.path.contains("sandboxReceipt"))"
    #endif
  }()

  /// The first URL scheme defined in the Info.plist. Assumes there's only one.
  let urlScheme: String = {
    guard let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else {
      return ""
    }

    var result = ""
    if let urlTypeDictionary = urlTypes.first,
      let urlSchemes = urlTypeDictionary["CFBundleURLSchemes"] as? [String],
      let urlScheme = urlSchemes.first {
      result = urlScheme
    }

    return result
  }()

  let interfaceType: String = {
    switch UIDevice.current.userInterfaceIdiom {
    case .pad:
      return "ipad"
    case .phone:
      return "iphone"
    case .mac:
      return "mac"
    case .carPlay:
      return "carplay"
    case .tv:
      return "tv"
    case .unspecified:
      fallthrough
    @unknown default:
      return "unspecified"
    }
  }()

  private let appInstallDate: Date? = {
    guard let urlToDocumentsFolder = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).last else {
      return nil
    }

    guard let installDate = try? FileManager.default.attributesOfItem(
      atPath: urlToDocumentsFolder.path
    )[FileAttributeKey.creationDate] as? Date else {
      return nil
    }
    return installDate
  }()

  private var daysSinceInstall: Int {
    let fromDate = appInstallDate ?? Date()
    let toDate = Date()
    let numberOfDays = Calendar.current.dateComponents([.day], from: fromDate, to: toDate)
    return numberOfDays.day ?? 0
  }

  private let localDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = Calendar.current.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private let utcDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private let utcTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()

  private let localDateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = Calendar.current.timeZone
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return formatter
  }()

  private let localTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = Calendar.current.timeZone
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()

  private let utcDateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return formatter
  }()

  private var localDateString: String {
    return localDateFormatter.string(from: Date())
  }

  private var localTimeString: String {
    return localTimeFormatter.string(from: Date())
  }

  private var localDateTimeString: String {
    return localDateTimeFormatter.string(from: Date())
  }

  private var utcDateString: String {
    return utcDateFormatter.string(from: Date())
  }

  private var utcTimeString: String {
    return utcTimeFormatter.string(from: Date())
  }

  private var utcDateTimeString: String {
    return utcDateTimeFormatter.string(from: Date())
  }

  private var minutesSinceInstall: Int {
    let fromDate = appInstallDate ?? Date()
    let toDate = Date()
    let numberOfMinutes = Calendar.current.dateComponents([.minute], from: fromDate, to: toDate)
    return numberOfMinutes.minute ?? 0
  }

  private var daysSinceLastPaywallView: Int? {
    guard let fromDate = storage.get(LastPaywallView.self) else {
      return nil
    }
    let toDate = Date()
    let numberOfDays = Calendar.current.dateComponents([.day], from: fromDate, to: toDate)
    return numberOfDays.day
  }

  private var minutesSinceLastPaywallView: Int? {
    guard let fromDate = storage.get(LastPaywallView.self) else {
      return nil
    }
    let toDate = Date()
    let numberOfMinutes = Calendar.current.dateComponents([.minute], from: fromDate, to: toDate)
    return numberOfMinutes.minute
  }

  private var totalPaywallViews: Int {
    return storage.get(TotalPaywallViews.self) ?? 0
  }

  func getDeviceAttributes(
    since event: EventData?,
    computedPropertyRequests: [ComputedPropertyRequest]
  ) async -> [String: Any] {
    var dictionary = await getTemplateDevice()

    let computedProperties = await getComputedDevicePropertiesSinceEvent(
      event,
      requests: computedPropertyRequests
    )
    dictionary += computedProperties
    return dictionary
  }

  private func getComputedDevicePropertiesSinceEvent(
    _ event: EventData?,
    requests computedPropertyRequests: [ComputedPropertyRequest]
  ) async -> [String: Any] {
    var output: [String: Any] = [:]

    for computedPropertyRequest in computedPropertyRequests {
      if let value = await storage.coreDataManager.getComputedPropertySinceEvent(
        event,
        request: computedPropertyRequest
      ) {
        output[computedPropertyRequest.type.prefix + computedPropertyRequest.eventName] = value
      }
    }

    return output
  }

  private func getTemplateDevice() async -> [String: Any] {
    let identityInfo = await factory.makeIdentityInfo()
    let aliases = [identityInfo.aliasId]

    let template = DeviceTemplate(
      publicApiKey: storage.apiKey,
      platform: isMac ? "macOS" : "iOS",
      appUserId: identityInfo.appUserId ?? "",
      aliases: aliases,
      vendorId: vendorId,
      appVersion: appVersion,
      osVersion: osVersion,
      deviceModel: model,
      deviceLocale: locale,
      deviceLanguageCode: languageCode,
      deviceCurrencyCode: currencyCode,
      deviceCurrencySymbol: currencySymbol,
      interfaceType: interfaceType,
      timezoneOffset: Int(TimeZone.current.secondsFromGMT()),
      radioType: radioType,
      interfaceStyle: interfaceStyle,
      isLowPowerModeEnabled: isLowPowerModeEnabled == "true",
      bundleId: bundleId,
      appInstallDate: appInstalledAtString,
      isMac: isMac,
      daysSinceInstall: daysSinceInstall,
      minutesSinceInstall: minutesSinceInstall,
      daysSinceLastPaywallView: daysSinceLastPaywallView,
      minutesSinceLastPaywallView: minutesSinceLastPaywallView,
      totalPaywallViews: totalPaywallViews,
      utcDate: utcDateString,
      localDate: localDateString,
      utcTime: utcTimeString,
      localTime: localTimeString,
      utcDateTime: utcDateTimeString,
      localDateTime: localDateTimeString,
      isSandbox: isSandbox,
      subscriptionStatus: Superwall.shared.subscriptionStatus.description,
      isFirstAppOpen: isFirstAppOpen
    )

    return template.toDictionary()
  }

  private unowned let storage: Storage
  private unowned let factory: IdentityInfoFactory & LocaleIdentifierFactory

  init(
    api: Api,
    storage: Storage,
    factory: IdentityInfoFactory & LocaleIdentifierFactory
  ) {
    self.storage = storage
    self.appInstalledAtString = appInstallDate?.isoString ?? ""
    self.factory = factory
    reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, api.hostDomain)
  }
}
