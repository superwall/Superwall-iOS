//
//  File.swift
//
//  Created by Jake Mor on 8/10/21.
//

import UIKit
import Foundation
import SystemConfiguration
import CoreTelephony

final class DeviceHelper {
  static let shared = DeviceHelper()
  let reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, Api.hostDomain)
  var appVersion: String {
    Bundle.main.releaseVersionNumber ?? ""
  }

  var osVersion: String {
    let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
    return String(
      format: "%ld.%ld.%ld",
      arguments: [systemVersion.majorVersion, systemVersion.minorVersion, systemVersion.patchVersion]
    )
  }

	var isMac: Bool {
		var output = false
		if #available(iOS 14.0, *) {
			output = ProcessInfo.processInfo.isiOSAppOnMac
		}
		return output
	}

  var model: String {
    UIDevice.modelName
  }

  var vendorId: String {
    UIDevice.current.identifierForVendor?.uuidString ?? ""
  }

  var locale: String {
    LocalizationManager.shared.selectedLocale ?? Locale.autoupdatingCurrent.identifier
  }

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

	var radioType: String {
		guard let reachability = reachability else {
			return "No Internet"
		}

		var flags = SCNetworkReachabilityFlags()
		SCNetworkReachabilityGetFlags(reachability, &flags)

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
		if #available(iOS 12.0, *) {
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
		} else {
			return "Unavailable"
		}
	}

	var isLowPowerModeEnabled: String {
    return ProcessInfo.processInfo.isLowPowerModeEnabled ? "true" : "false"
	}

	var bundleId: String {
		return Bundle.main.bundleIdentifier ?? ""
	}

  var appInstallDate: Date? = {
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

  var appInstalledAtString: String {
    return appInstallDate?.isoString ?? ""
  }

  var daysSinceInstall: Int {
    let fromDate = appInstallDate ?? Date()
    let toDate = Date()
    let numberOfDays = Calendar.current.dateComponents([.day], from: fromDate, to: toDate)
    return numberOfDays.day ?? 0
  }

  var minutesSinceInstall: Int {
    let fromDate = appInstallDate ?? Date()
    let toDate = Date()
    let numberOfMinutes = Calendar.current.dateComponents([.minute], from: fromDate, to: toDate)
    return numberOfMinutes.minute ?? 0
  }

  var daysSinceLastPaywallView: Int? {
    guard let fromDate = Storage.shared.getLastPaywallView() else {
      return nil
    }
    let toDate = Date()
    let numberOfDays = Calendar.current.dateComponents([.day], from: fromDate, to: toDate)
    return numberOfDays.day
  }

  var minutesSinceLastPaywallView: Int? {
    guard let fromDate = Storage.shared.getLastPaywallView() else {
      return nil
    }
    let toDate = Date()
    let numberOfMinutes = Calendar.current.dateComponents([.minute], from: fromDate, to: toDate)
    return numberOfMinutes.minute
  }

  var templateDevice: TemplateDevice {
    let aliases: [String]
    if let alias = Storage.shared.aliasId {
      aliases = [alias]
    } else {
      aliases = []
    }

    return TemplateDevice(
      publicApiKey: Storage.shared.apiKey,
      platform: DeviceHelper.shared.isMac ? "macOS" : "iOS",
      appUserId: Storage.shared.appUserId ?? "",
      aliases: aliases,
      vendorId: DeviceHelper.shared.vendorId,
      appVersion: DeviceHelper.shared.appVersion,
      osVersion: DeviceHelper.shared.osVersion,
      deviceModel: DeviceHelper.shared.model,
      deviceLocale: DeviceHelper.shared.locale,
      deviceLanguageCode: DeviceHelper.shared.languageCode,
      deviceCurrencyCode: DeviceHelper.shared.currencyCode,
      deviceCurrencySymbol: DeviceHelper.shared.currencySymbol,
      timezoneOffset: Int(TimeZone.current.secondsFromGMT()),
      radioType: DeviceHelper.shared.radioType,
      interfaceStyle: DeviceHelper.shared.interfaceStyle,
      isLowPowerModeEnabled: DeviceHelper.shared.isLowPowerModeEnabled == "true",
      bundleId: DeviceHelper.shared.bundleId,
      appInstallDate: DeviceHelper.shared.appInstalledAtString,
      isMac: DeviceHelper.shared.isMac,
      daysSinceInstall: DeviceHelper.shared.daysSinceInstall,
      minutesSinceInstall: DeviceHelper.shared.minutesSinceInstall,
      daysSinceLastPaywallView: DeviceHelper.shared.daysSinceLastPaywallView,
      minutesSinceLastPaywallView: DeviceHelper.shared.minutesSinceLastPaywallView
    )
  }
}
