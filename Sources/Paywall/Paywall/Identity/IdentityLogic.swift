//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/09/2022.
//

import Foundation

enum IdentityLogic {
  struct func logIn(
    newUserId: String,
    oldUserId: String?
  ) {
    i
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
