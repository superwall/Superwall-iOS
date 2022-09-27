//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/09/2022.
//

import Foundation

/// The error returned when trying to interact with the identity API.
public enum IdentityError: Error {
  /// The `userId` that was provided was empty.
  case missingUserId

  /// The user is already logged in.
  case alreadyLoggedIn

  /// The user isn't logged in.
  case notLoggedIn
}
