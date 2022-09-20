//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/09/2022.
//

import Foundation

enum IdentityLogic {
  enum IdentifyOutcome {
    case reset
    case loadAssignments
  }
  
  static func logIn(
    newUserId: String,
    oldUserId: String?
  ) {

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
