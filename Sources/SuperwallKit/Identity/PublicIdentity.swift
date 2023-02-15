//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation

// MARK: - Identify
public extension Superwall {
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
  ///  - Throws: An error of type ``IdentityError``.
  @objc func identify(
    userId: String,
    options: IdentityOptions? = nil
  ) async throws {
    try await dependencyContainer.identityManager.identify(
      userId: userId,
      options: options
    )
  }

  /// Creates an account with Superwall. This links a `userId` to Superwall's automatically generated alias.
  ///
  /// Call this as soon as you have a `userId`.
  ///
  ///  - Parameters:
  ///     - userId: Your user's unique identifier, as defined by your backend system.
  ///  - Throws: An error of type ``IdentityError``.
  @available(swift, obsoleted: 1.0)
  @objc func identify(
    userId: String
  ) async throws {
    try await identify(userId: userId)
  }

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
  ///     - completion: An optional completion block that accepts a `success` state when Superwall has
  ///     finished configuring. Otherwise it accepts a `failure` state with an error of type ``IdentityError``.
  @nonobjc
  func identify(
    userId: String,
    options: IdentityOptions? = nil,
    completion: ((IdentityError?) -> Void)? = nil
  ) {
    Task {
      do {
        try await identify(userId: userId, options: options)
        await MainActor.run {
          completion?(nil)
        }
      } catch let error as IdentityError {
        await MainActor.run {
          completion?(error)
        }
      }
    }
  }
}

// MARK: - Reset
public extension Superwall {
  /// Resets the `userId`, on-device paywall assignments, and data stored
  /// by Superwall.
  @objc func reset() async {
    presentationItems.reset()
    dependencyContainer.identityManager.reset()
    await dependencyContainer.storage.reset()
    await dependencyContainer.paywallManager.resetCache()
    dependencyContainer.configManager.reset()
    dependencyContainer.identityManager.didSetIdentity()
  }

  /// Resets the `userId`, on-device paywall assignments, and data stored
  /// by Superwall.
  ///
  /// - Parameters:
  ///   - completion: A completion block that is called when reset has completed.
  @nonobjc
  func reset(completion: (() -> Void)? = nil) {
    Task {
      await reset()
      await MainActor.run {
        completion?()
      }
    }
  }
}
