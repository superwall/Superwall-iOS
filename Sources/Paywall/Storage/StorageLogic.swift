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
    case checkForStaticConfigUpgrade
    case loadAssignments
    case nonBlockingAssignmentDelay
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
    withUserId newUserId: String,
    oldUserId: String?,
    hasTriggerDelay: Bool
  ) -> IdentifyOutcome {
    // if there was a previously set userId ...
    if let oldUserId = oldUserId {
      // Check if the userId changed. If it hasn't, check for a static config upgrade.
      if newUserId == oldUserId {
        return .checkForStaticConfigUpgrade
      } else {
        // Otherwise, call reset.
        return .reset
      }
    }
    // Else, if user has gone from anonymous to having an ID...
    // If config hasn't been retrieved return a non-blocking delay to retrieve assignments
    if hasTriggerDelay {
      return .nonBlockingAssignmentDelay
    }

    // Else, get assignments if config has been retrieved.
    return .loadAssignments
  }
}
