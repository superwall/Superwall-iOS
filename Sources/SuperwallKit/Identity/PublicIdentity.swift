//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation

// MARK: - Identify
extension Superwall {
  /// Creates an account with Superwall. This links a `userId` to Superwall's automatically generated alias.
  ///
  /// Call this as soon as you have a `userId`.
  ///
  ///  - Parameters:
  ///     - userId: Your user's unique identifier, as defined by your backend system.
  ///     - options: An ``IdentityOptions`` object, whose property
  ///     ``IdentityOptions/restorePaywallAssignments`` you can set to `true`
  ///     to tell the SDK to wait to restore paywall assignments from the server before presenting any paywalls.
  ///     This should only be used in advanced use cases. If you expect
  ///     users of your app to switch accounts or delete/reinstall a lot, you'd set this when users log in to an
  ///     existing account.
  public func identify(
    userId: String,
    options: IdentityOptions? = nil
  ) {
    dependencyContainer.identityManager.identify(
      userId: userId,
      options: options
    )
  }

  /// Objective-C-only method. Creates an account with Superwall. This links a `userId` to Superwall's automatically generated alias.
  ///
  /// Call this as soon as you have a `userId`.
  ///
  ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
  @available(swift, obsoleted: 1.0)
  public func identify(userId: String) {
    identify(userId: userId, options: nil)
  }
}
