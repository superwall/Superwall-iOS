//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/09/2022.
//

import Foundation

/// The error returned when trying to create an account.
@objc(SWKIdentityError)
public enum IdentityError: Int, Error {
  /// The user is already logged in.
  case alreadyLoggedIn

  /// The `userId` that was provided was empty.
  case missingUserId
}

/// The error returned when trying to logout a user out.
@objc(SWKLogoutError)
public enum LogoutError: Int, Error {
  /// The user isn't logged in.
  case notLoggedIn
}
