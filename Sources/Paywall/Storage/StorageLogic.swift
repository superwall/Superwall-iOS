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
    case loadAssignments
  }

  static func identify(
    newUserId: String,
    oldUserId: String?
  ) -> IdentifyOutcome? {
    let hasOldUserId = oldUserId != nil

    if hasOldUserId {
      if newUserId == oldUserId {
        return nil
      } else {
        return .reset
      }
    }

    return .loadAssignments
  }
}
