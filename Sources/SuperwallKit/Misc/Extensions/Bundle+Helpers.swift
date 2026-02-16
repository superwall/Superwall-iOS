//
//  Bundle+Helpers.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//

import Foundation

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

  var receiptSpecificAppVersion: String? {
    #if targetEnvironment(macCatalyst) || os(macOS)
    let dictKey = "CFBundleShortVersionString"
    #else
    let dictKey = "CFBundleVersion"
    #endif

    guard let version = infoDictionary?[dictKey] as? String else {
      return nil
    }

    return version
  }
}
