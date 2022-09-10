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
    case doNothing
    case loadAssignments
    case enqueBlockingAssignments
    case enqueNonBlockingAssignments
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
    newUserId: String?,
    oldUserId: String?,
    didResetViaIdentify: Bool,
    isFreshInstall: Bool,
    isFirstStaticConfigCall: Bool,
    hasConfigReturned: Bool
  ) -> IdentifyOutcome {

    // helper variables
    let hasNewUserId = newUserId != nil
    let hasOldUserId = oldUserId != nil

    // if we are reseting as a result of calling identify with
    // a new id, block assignments since the user is switching
    // from a logged in account to another logged in account
    if didResetViaIdentify {
      // reset the flag
      TriggerDelayManager.shared.appUserIdAfterReset = nil
      return .enqueBlockingAssignments
    }

    // if this is a fresh install, we load assignments
    // if a user id is provided. no need to check for a
    // static config update
    if isFreshInstall {
      if hasNewUserId {
        // it's a fresh install and we have an id, so we
        // need to load assignments
        if hasConfigReturned {
          return .loadAssignments
        } else {
          return .enqueBlockingAssignments
        }
      } else {
        // it's a fresh install and we have no userId, no need
        // to do anything since we for sure won't have assignments
        // for them
        return .doNothing
      }
    }

    // if the user is passing through a new user id and hasn't called
    // reset in between, we automattically call reset for them
    if (hasOldUserId && hasNewUserId) && newUserId != oldUserId  {
        // reset via identify, the UIDs have changed
        return .reset
    }

    // this isn't a fresh install, so we need to check if this is
    // their first static config upgrade. If we don't have assignments
    // on disk, we should wait for config & assignments to return before
    // firing any triggers. logic is the same regardless of what app user
    // ids are passed through
    if isFirstStaticConfigCall {
      if hasConfigReturned {
        // config returned so there are likely no pending triggers, just
        // load assignments
        return .loadAssignments
      } else {
        // we're still waiting for static config to return,
        // we enque assignments and block triggers from happening
        // until we receive assignments
        return .enqueBlockingAssignments
      }
    }

    // if we're receiving a new user id, and we've made it this far,
    // this is just a plain old identify() call, so load assignments
    // if the user id has changed
    if hasNewUserId && !hasOldUserId {
      return .enqueBlockingAssignments
    } else {
      // if we've made it this far, we have assignments on disk
      // for an existing user and there is no need to do anything
      return .doNothing
    }


  }
}
