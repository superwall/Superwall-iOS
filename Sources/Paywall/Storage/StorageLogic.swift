//
//  StoreLogic.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

enum StorageLogic {
  enum IdentifyOutcome {
    case reset
    case staticConfigUpgrade
    case loadAssignments
    case loadAssignmentsPostConfig
    case staticConfigUpgradePostConfig
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

  static func identify(
    hasNewUserId: Bool,
    hasOldUserId: Bool,
    hasConfig: Bool,
    isFirstAppOpen: Bool,
    isUpdatingToStaticConfig: Bool
  ) -> IdentifyOutcome? {


    if isUpdatingToStaticConfig {
      if hasNewUserId && hasOldUserId {

      }

      if hasNewUserId && !hasOldUserId

    }




    // If user hasn't passed in a userId, but an old userId exists
    // Check for static config upgrade.
    if newUserId == nil,
     oldUserId != nil {
      return .checkForStaticConfigUpgrade
    }

    // if its the first app open since install, and there is no userId being passed in
    if newUserId == nil && oldUserId == nil && isFirstAppOpen {
      return nil // do nothing
    }

    // if it is the first install, but an appUserId is being passed through
    if newUserId != nil && oldUserId == nil && isFirstAppOpen {
      return hasConfig ? .loadAssignments : .loadAssignmentsPostConfig
    }

    // If the userId hasn't changed (including if they stay anonymous)
    // Check for a static config upgrade.
    if newUserId == oldUserId {
      return .checkForStaticConfigUpgrade
    }

    // Else, if the userId already existed and has now changed, call reset.
    if let oldUserId = oldUserId,
      newUserId != oldUserId {
      return .reset
    }


    // Else, get assignments if config has been retrieved, otherwise wait
    return hasConfig ? .loadAssignments : .loadAssignmentsPostConfig
  }
}
