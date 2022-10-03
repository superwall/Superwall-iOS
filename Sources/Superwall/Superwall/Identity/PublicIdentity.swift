//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation

// MARK: - Log In
public extension Superwall {
  /// Logs in a user with their `userId` to retrieve paywalls that they've been assigned to.
  ///
  /// This links a `userId` to Superwall's automatically generated alias. Call this once after you've retrieved a userId.
  ///
  /// The user will stay logged in until you call ``Superwall/Superwall/logOut()``. If you call this while they're already logged in, it will throw an error of type ``LogInError``.
  ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
  ///  - Returns: The shared Superwall instance.
  ///  - Throws: An error of type ``LogInError``.
  @discardableResult
  @objc static func logIn(userId: String) async throws -> Superwall {
    try await IdentityManager.shared.logIn(userId: userId)
    return shared
  }

  /// Logs in a user with their `userId` to retrieve paywalls that they've been assigned to.
  ///
  /// This links a `userId` to Superwall's automatically generated alias. Call this as soon as you have a userId. If a user with a different id was previously identified, calling this will automatically call `Superwall.reset()`
  ///  - Parameters:
  ///   - userId: Your user's unique identifier, as defined by your backend system.
  ///   - completion: A completion block that accepts a `Result` enum. Its success value is
  ///   the shared Superwall instance, and its failure error is of type ``LogInError``.
  static func logIn(
    userId: String,
    completion: ((Result<Superwall, LogInError>) -> Void)?
  ) {
    Task {
      do {
        let shared = try await logIn(userId: userId)
        await MainActor.run {
          completion?(.success(shared))
        }
      } catch let error as LogInError {
        await MainActor.run {
          completion?(.failure(error))
        }
      }
    }
  }
}

// MARK: - Create Account
public extension Superwall {
  /// Creates an account with Superwall. This links a `userId` to Superwall's automatically generated alias.
  ///
  /// Call this as soon as you have a `userId`. If you are logging in an existing user, you should use
  /// ``Superwall/Superwall/logIn(userId:)`` instead, as that will retrieve their assigned paywalls.
  ///
  ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
  ///  - Returns: The shared Superwall instance.
  ///  - Throws: An error of type ``CreateAccountError``.
  @discardableResult
  @objc static func createAccount(userId: String) throws -> Superwall {
    try IdentityManager.shared.createAccount(userId: userId)
    return shared
  }
}

// MARK: - Log Out
public extension Superwall {
  /// Logs out the user. This calls ``Superwall/Superwall/reset()``, which resets on-device paywall
  /// assignments and the `userId` stored by Superwall.
  ///
  /// You must call this method before attempting to log in a new user.
  /// If a user isn't already logged in before calling this method, an error will be thrown.
  ///
  ///  - Throws: An error of type ``LogoutError``.
  @objc static func logOut() async throws {
    try await IdentityManager.shared.logOut()
  }

  /// Logs out the user. This calls ``Superwall/Superwall/reset()``, which resets on-device paywall
  /// assignments and the `userId` stored by Superwall.
  ///
  /// You must call this method before attempting to log in a new user.
  /// If a user isn't already logged in before calling this method, an error will be thrown.
  ///
  /// - Parameters:
  ///   - completion: A completion block that accepts a `Result` object.
  ///   The `Result`'s success value is `Void` and failure error is of type ``LogoutError``.
  static func logOut(completion: ((Result<Void, LogoutError>) -> Void)? = nil) {
    Task {
      do {
        try await logOut()
        await MainActor.run {
          completion?(.success(()))
        }
      } catch let error as LogoutError {
        await MainActor.run {
          completion?(.failure(error))
        }
      }
    }
  }
}

// MARK: - Reset
public extension Superwall {
  /// Resets the `userId`, on-device paywall assignments, and data stored
  /// by Superwall.
  ///
  /// - Returns:The shared ``Superwall/Superwall`` instance on the main thread.
  @discardableResult
  @objc static func reset() async -> Superwall {
    shared.lastSuccessfulPresentationRequest = nil
    shared.latestDismissedPaywallInfo = nil
    shared.presentationPublisher?.cancel()
    shared.presentationPublisher = nil
    trackCancellable?.cancel()
    trackCancellable = nil

    IdentityManager.shared.clear()
    Storage.shared.clear()
    await PaywallManager.shared.clearCache()

    ConfigManager.shared.reset()
    IdentityManager.shared.forceHasIdentity()

    return await MainActor.run {
      return shared
    }
  }

  /// Asynchronously resets the `userId` and data stored by Superwall.
  ///
  /// - Parameters:
  ///   - completion: A completion block that accepts the shared ``Superwall/Superwall`` object.
  static func reset(completion: ((Superwall) -> Void)? = nil) {
    Task {
      await reset()
      await MainActor.run {
        completion?(shared)
      }
    }
  }
}
