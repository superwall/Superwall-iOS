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
	let reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, Network.shared.hostDomain)
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

  var appInstallDate: String = {
    guard let urlToDocumentsFolder = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).last else {
      return ""
    }

    guard let installDate = try? FileManager.default.attributesOfItem(
      atPath: urlToDocumentsFolder.path
    )[FileAttributeKey.creationDate] as? Date else {
      return ""
    }

    return installDate.isoString
  }()

  var templateDevice: TemplateDevice {
    let aliases: [String]
    if let alias = Store.shared.aliasId {
      aliases = [alias]
    } else {
      aliases = []
    }

    return TemplateDevice(
      publicApiKey: Store.shared.apiKey ?? "",
      platform: "iOS",
      appUserId: Store.shared.appUserId ?? "",
      aliases: aliases,
      vendorId: DeviceHelper.shared.vendorId,
      appVersion: DeviceHelper.shared.appVersion,
      osVersion: DeviceHelper.shared.osVersion,
      deviceModel: DeviceHelper.shared.model,
      deviceLocale: DeviceHelper.shared.locale,
      deviceLanguageCode: DeviceHelper.shared.languageCode,
      deviceCurrencyCode: DeviceHelper.shared.currencyCode,
      deviceCurrencySymbol: DeviceHelper.shared.currencySymbol
    )
  }
}

extension UIDevice {
  static var modelName: String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    return machineMirror.children.reduce("") { identifier, element in
      guard let value = element.value as? Int8, value != 0 else { return identifier }
      return identifier + String(UnicodeScalar(UInt8(value)))
    }
  }
}

extension Bundle {
  var superwallClientId: String? {
    return infoDictionary?["SuperwallClientId"] as? String
  }

  var releaseVersionNumber: String? {
    return infoDictionary?["CFBundleShortVersionString"] as? String
  }
  var buildVersionNumber: String? {
    return infoDictionary?["CFBundleVersion"] as? String
  }

  var applicationQuerySchemes: [String] {
    return infoDictionary?["LSApplicationQueriesSchemes"] as? [String] ?? []
  }
}
