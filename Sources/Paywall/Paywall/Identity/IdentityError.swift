//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/09/2022.
//

import Foundation

//TODO: FILL OUT INFO HERE AND EXPLAIN ON LOGIN ETC THAT THIS IS THROWN
public enum IdentityError: Error {
  case configNotCalled
  case missingAppUserId
  case alreadyLoggedIn
  case notLoggedIn
}
