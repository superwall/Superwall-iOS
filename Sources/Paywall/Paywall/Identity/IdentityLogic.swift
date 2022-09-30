//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/09/2022.
//

import Foundation

enum IdentityLogic {
  enum IdentityConfigurationAction {
    case reset
    case loadAssignments
  }

  static func generateAlias() -> String {
    return "$SuperwallAlias:\(UUID().uuidString)"
  }

  static func mergeAttributes(
    _ newAttributes: [String: Any],
    with oldAttributes: [String: Any]
  ) -> [String: Any] {
    var mergedAttributes = oldAttributes

    for key in newAttributes.keys {
      if key == "$is_standard_event" {
        continue
      }
      if key == "$application_installed_at" {
        continue
      }

      var key = key

      if key.starts(with: "$") { // replace dollar signs
        key = key.replacingOccurrences(of: "$", with: "")
      }

      if let value = newAttributes[key] {
        mergedAttributes[key] = value
      } else {
        mergedAttributes[key] = nil
      }
    }

    // we want camel case
    mergedAttributes["applicationInstalledAt"] = DeviceHelper.shared.appInstalledAtString

    return mergedAttributes
  }

  /// Logic to figure out whether to get assignments before firing triggers.
  ///
  /// The logic is:
  /// - If the appUserId exists, and existed PRE static config, get assignments.
  /// - If the appUserId exists, and existed POST static config, don't get assignments.
  /// - If they are anonymous, is NOT first app open since install, and existed PRE static config, get assignments.
  /// - If they are anonymous, is NOT first app open since install, and existed POST static config, don't get assignments.
  /// - If they are anonymous, IS first app open since install, existed PRE static, don't get assignments.
  /// - If they are anonymous, IS first app open since install, existed POST static, don't get assignments.
  static func shouldGetAssignments(
    hasAccount: Bool,
    accountExistedPreStaticConfig: Bool,
    isFirstAppOpen: Bool
  ) -> Bool {
    if hasAccount {
      if accountExistedPreStaticConfig {
        return true
      }
      return false
    }

    if isFirstAppOpen {
      return false
    }

    if accountExistedPreStaticConfig {
      return true
    }

    return false
  }
}
