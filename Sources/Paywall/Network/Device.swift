//
//  File.swift
//
//  Created by Jake Mor on 8/10/21.
//

import UIKit
import Foundation


internal class DeviceHelper {

    static let shared = DeviceHelper()
    
    var appVersion: String {
        get { Bundle.main.releaseVersionNumber ?? "" }
    }
    
 
    var osVersion: String {
        get {
            let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
            return String(format: "%ld.%ld.%ld", arguments: [systemVersion.majorVersion, systemVersion.minorVersion, systemVersion.patchVersion])
        }
    }
	
	var isMac: Bool {
		var output = false
		if #available(iOS 14.0, *) {
			output = ProcessInfo.processInfo.isiOSAppOnMac
		}
		return output
	}
    
    
    var model: String {
        get { UIDevice.modelName }
    }
    
    var vendorId: String {
        get { UIDevice.current.identifierForVendor?.uuidString ?? ""}
    }

    var locale: String {
		get { LocalizationManager.shared.selectedLocale ?? Locale.autoupdatingCurrent.identifier }
    }
    
    var languageCode: String {
        get { Locale.autoupdatingCurrent.languageCode ?? "" }
    }
    
    var currencyCode: String {
        get { Locale.autoupdatingCurrent.currencyCode ?? "" }
    }
    
    var currencySymbol: String {
        get { Locale.autoupdatingCurrent.currencySymbol ?? "" }
    }
    
    var secondsFromGMT: String {
        get {
            "\(Int(TimeZone.current.secondsFromGMT()))"
            
        }
    }
    
    var appInstallDate: String = {
        let urlToDocumentsFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        let installDate = try? FileManager.default.attributesOfItem(atPath: urlToDocumentsFolder.path)[FileAttributeKey.creationDate] as? Date
        return installDate?.isoString ?? ""
    }()
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
