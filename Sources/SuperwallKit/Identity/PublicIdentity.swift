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
  ///     - completion: An optional completion block that is called when Superwall has
  ///     finished configuring. Accepts an error.
  @objc public func identify(
    userId: String,
    options: IdentityOptions? = nil,
    completion: ((Error?) -> Void)? = nil
  ) {
    Task {
      do {
        try await dependencyContainer.identityManager.identify(
          userId: userId,
          options: options
        )
        await MainActor.run {
          completion?(nil)
        }
      } catch {
        await MainActor.run {
          completion?(error)
        }
      }
    }
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
  ///     - completion: An optional completion block that is called when Superwall has
  ///     finished configuring. Accepts an error.
  @nonobjc
  public func identify(
    userId: String,
    options: IdentityOptions? = nil
  ) async throws {
    try await dependencyContainer.identityManager.identify(
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
  public func identify(userId: String) {
    identify(userId: userId, options: nil, completion: nil)
  }

  /// Objective-C only method. Creates an account with Superwall. This links a `userId` to Superwall's automatically generated alias.
  ///
  /// Call this as soon as you have a `userId`.
  ///
  ///  - Parameters:
  ///     - userId: Your user's unique identifier, as defined by your backend system.
  ///     - completion: An optional completion block that is called when Superwall has
  ///     finished configuring. Accepts an error.
  @available(swift, obsoleted: 1.0)
  public func identify(
    userId: String,
    completion: ((Error?) -> Void)?
  ) {
    identify(
      userId: userId,
      options: nil,
      completion: completion
    )
  }
}

// MARK: - Reset
extension Superwall {
  /// Resets the `userId`, on-device paywall assignments, and data stored
  /// by Superwall.
  ///
  /// - Parameter completion: An optional completion block that is called when reset has completed.
  public func reset(completion: (() -> Void)? = nil) {
    Task {
      await reset()
      await MainActor.run {
        completion?()
      }
    }
  }

  /// Objective-C only method. Resets the `userId`, on-device paywall assignments, and data stored
  /// by Superwall.
  @available(swift, obsoleted: 1.0)
  public func reset() {
    reset(completion: nil)
  }

  /// Resets the `userId`, on-device paywall assignments, and data stored
  /// by Superwall.
  @nonobjc
  public func reset() async {
    presentationItems.reset()
    dependencyContainer.identityManager.reset()
    await dependencyContainer.storage.reset()
    await dependencyContainer.paywallManager.resetCache()
    dependencyContainer.configManager.reset()
    dependencyContainer.identityManager.didSetIdentity()
  }
}
