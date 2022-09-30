//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/09/2022.
//

import Foundation

/// The error returned when trying to create an account.
public enum CreateAccountError: Error {
  /// The user is already logged in.
  case alreadyLoggedIn

  /// The `userId` that was provided was empty.
  case missingUserId
}

/// The error returned when trying to logout a user out.
public enum LogoutError: Error {
  /// The user isn't logged in.
  case notLoggedIn
}

/// The error returned when trying to log a user in.
public enum LogInError: Error {
  /// The user is already logged in.
  case alreadyLoggedIn

  /// The `userId` that was provided was empty.
  case missingUserId
}
