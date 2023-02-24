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
  ) throws {
    try dependencyContainer.identityManager.identify(
      userId: userId,
      options: options
    )
  }

  /// Objective-C only method. Creates an account with Superwall. This links a `userId` to Superwall's automatically generated alias.
  ///
  /// Call this as soon as you have a `userId`.
  ///
  ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
  @available(swift, obsoleted: 1.0)
  public func identify(userId: String) throws {
    try identify(userId: userId, options: nil)
  }
}

// MARK: - Reset
extension Superwall {
  /// Resets the `userId`, on-device paywall assignments, and data stored
  /// by Superwall.
  public func reset() {
    Task {
      internalReset()
    }
  }

  /// Asynchronously resets. Presentation of paywalls is suspended until reset completes.
  func internalReset() {
    dependencyContainer.identityManager.reset()
    dependencyContainer.storage.reset()
    dependencyContainer.paywallManager.resetCache()
    presentationItems.reset()
    dependencyContainer.configManager.reset()
    dependencyContainer.identityManager.didSetIdentity()
  }
}
