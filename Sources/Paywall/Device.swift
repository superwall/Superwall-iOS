//
//  File.swift
//
//  Created by Jake Mor on 8/10/21.
//

import UIKit
import Foundation

struct Device: Codable {
    var app_version: String
    var os_version: String
    var model: String
    var vendor_id: String
}

class DeviceHelper {
    internal static func device() -> Device {
        return Device(
            app_version: shared.appVersion,
            os_version: shared.osVersion,
            model: shared.model,
            vendor_id: shared.vendorId
        )
    }
    
    private static let shared = DeviceHelper()
    
    private let appVersionOnce:Once<DeviceHelper, String> = Once { myself in Bundle.main.releaseVersionNumber }
   
    var appVersion: String {
        get { self.appVersionOnce.once(self, defaultValue: "") }
    }
    
    private let osVersionOnce:Once<DeviceHelper, String> = Once { myself in
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
        return String(format: "%ld.%ld.%ld", arguments: [systemVersion.majorVersion, systemVersion.minorVersion, systemVersion.patchVersion])
    }
    
    var osVersion: String {
        get { self.osVersionOnce.once(self, defaultValue: "") }
    }
    
    private let modelOnce:Once<DeviceHelper, String> = Once { myself in
        return UIDevice.modelName
    }
    
    var model: String {
        get { modelOnce.once(self, defaultValue: "") }
    }
    
    private let vendorIdOnce:Once<DeviceHelper, String> = Once { myself in
        return UIDevice.current.identifierForVendor?.uuidString
    }
    var vendorId: String {
        get { vendorIdOnce.once(self, defaultValue: "") }
    }
}



class Once<Input,Output> {
    let block:(Input)->Output?
    private var cache:Output? = nil

    init(_ block:@escaping (Input)->Output?) {
        self.block = block
    }

    func once(_ input:Input, defaultValue: Output) -> Output {
        // If the cache is nil, we're assuming we haven't run this before
        guard let resolved = self.cache else {
            
            // Try to resolve the value
            let outputOptional = self.block(input)
            
            // If we got a nil, apply the defualt value
            guard let output = outputOptional else {
                self.cache = defaultValue
                return defaultValue
            }
            self.cache = output
            return output
        }
        return resolved
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
