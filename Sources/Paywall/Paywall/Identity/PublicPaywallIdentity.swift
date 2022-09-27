//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation

// MARK: - Log In
public extension Paywall {
  /// Logs in a user with their `userId` to retrieve paywalls that they've been assigned to.
  ///
  /// This links a `userId` to Superwall's automatically generated alias. Call this once after you've retrieved a userId.
  ///
  /// The user will stay logged in until you call ``Paywall/Paywall/logOut()`` or ``Paywall/Paywall/reset()``. If you call
  /// this while they're already logged in, it will throw a ``IdentityError/alreadyLoggedIn`` error.
  ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
  ///  - Returns: The shared Paywall instance.
  @discardableResult
  @objc static func logIn(userId: String) async throws -> Paywall {
    try await IdentityManager.shared.logIn(userId: userId)
    return shared
  }

  /// Log in a user with their userId to retrieve paywalls that they've been assigned to.
  ///
  /// This links a `userId` to Superwall's automatically generated alias. Call this as soon as you have a userId. If a user with a different id was previously identified, calling this will automatically call `Paywall.reset()`
  ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
  ///  - Returns: The shared Paywall instance.
  @available (*, unavailable)
  @objc static func logIn(
    userId: String,
    completion: ((Paywall?, Error?) -> Void)?
  ) {
    Task {
      do {
        let shared = try await logIn(userId: userId)
        await MainActor.run {
          completion?(shared, nil)
        }
      } catch {
        await MainActor.run {
          completion?(nil, error)
        }
      }
    }
  }

  /// Log in a user with their userId to retrieve paywalls that they've been assigned to.
  ///
  /// This links a `userId` to Superwall's automatically generated alias. Call this as soon as you have a userId. If a user with a different id was previously identified, calling this will automatically call `Paywall.reset()`
  ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
  ///  - Returns: The shared Paywall instance.
  static func logIn(
    userId: String,
    completion: ((Result<Paywall, Error>) -> Void)?
  ) {
    Task {
      do {
        let shared = try await logIn(userId: userId)
        await MainActor.run {
          completion?(.success(shared))
        }
      } catch {
        completion?(.failure(error))
      }
    }
  }
}

// MARK: - Create Account
public extension Paywall {
  /// Log in a user with their userId to retrieve paywalls that they've been assigned to.
  ///
  /// This links a `userId` to Superwall's automatically generated alias. Call this as soon as you have a userId. If a user with a different id was previously identified, calling this will automatically call `Paywall.reset()`
  ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
  ///  - Returns: The shared Paywall instance.
  @discardableResult
  @objc static func createAccount(userId: String) throws -> Paywall {
    try IdentityManager.shared.createAccount(userId: userId)
    return shared
  }
}

// MARK: - Log Out
public extension Paywall {
  /// Log in a user with their userId to retrieve paywalls that they've been assigned to.
  ///
  /// This links a `userId` to Superwall's automatically generated alias. Call this as soon as you have a userId. If a user with a different id was previously identified, calling this will automatically call `Paywall.reset()`
  ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
  ///  - Returns: The shared Paywall instance.
  @objc static func logOut() async throws {
    try await IdentityManager.shared.logOut()
  }

  /// Log in a user with their userId to retrieve paywalls that they've been assigned to.
  ///
  /// This links a `userId` to Superwall's automatically generated alias. Call this as soon as you have a userId. If a user with a different id was previously identified, calling this will automatically call `Paywall.reset()`
  ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
  ///  - Returns: The shared Paywall instance.
  @objc static func logOut(completion: (() -> Void)?) throws {
    Task {
      try await logOut()
      await MainActor.run {
        completion?()
      }
    }
  }
}

// MARK: - Reset
public extension Paywall {
  /// Resets the `userId` and data stored by Superwall.
  @discardableResult
  @objc static func reset() async -> Paywall {
    Paywall.shared.lastSuccessfulPresentationRequest = nil
    shared.latestDismissedPaywallInfo = nil
    IdentityManager.shared.clear()
    Storage.shared.clear()
    ConfigManager.shared.clear()
    await PaywallManager.shared.clearCache()

    // TODO: Maybe change this and get assignments?
    await ConfigManager.shared.fetchConfiguration()
    return shared
  }

  /// Resets the `userId` and data stored by Superwall.
  @objc static func reset(completion: ((Paywall) -> Void)?) {
    Task {
      await reset()
      await MainActor.run {
        completion?(shared)
      }
    }
  }
}
