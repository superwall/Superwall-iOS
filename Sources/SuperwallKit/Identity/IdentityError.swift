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
  /// The `userId` that was provided was empty.
  case missingUserId

  public var localizedDescription: String {
    switch self {
    case .missingUserId:
      return "The provided userId was empty."
    }
  }
}
