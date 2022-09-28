//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/09/2022.
//

import Foundation
import Combine

final class IdentityManager {
  static let shared = IdentityManager()
  var aliasId: String {
    didSet {
      saveIds()
    }
  }
  var appUserId: String? {
    didSet {
      saveIds()
    }
  }
  var userId: String {
    return appUserId ?? aliasId
  }
  var userAttributes: [String: Any] = [:]

  /// When `true`, the SDK is able to fire triggers.
  private var identitySubject = CurrentValueSubject<Bool, Never>(false)

  /// A Publisher that only emits when `identitySubject` is `true`. When `true`,
  /// it means the SDK is ready to fire triggers.
  static var hasIdentity: AnyPublisher<Bool, Error> {
    shared.identitySubject
      .filter { $0 == true }
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }

  private let storage: Storage
  private let configManager: ConfigManager

  /// Only use init for testing purposes. Otherwise use `shared`.
  init(
    storage: Storage = .shared,
    configManager: ConfigManager = .shared
  ) {
    self.storage = storage
    self.configManager = configManager
    self.appUserId = storage.get(AppUserId.self)
    self.aliasId = storage.get(AliasId.self) ?? IdentityLogic.generateAlias()
    self.userAttributes = storage.get(UserAttributes.self) ?? [:]
  }

  /// Waits for config to return before getting assignments (if needed).
  func configure() async {
    await configManager.$config.hasValue()

    let hasAccount = appUserId != nil
    let accountExistedPreStaticConfig = storage.neverCalledStaticConfig
    let isFirstAppOpen = !(storage.get(DidTrackFirstSeen.self) ?? false)

    if IdentityLogic.shouldGetAssignments(
      hasAccount: hasAccount,
      accountExistedPreStaticConfig: accountExistedPreStaticConfig,
      isFirstAppOpen: isFirstAppOpen
    ) {
      await configManager.getAssignments()
    }

    identitySubject.send(true)
  }

  /// Logs user in and waits for config then assignments.
  ///
  /// - Throws: An error of type ``IdentityError``.
  func logIn(userId: String) async throws {
    guard appUserId == nil else {
      throw IdentityError.alreadyLoggedIn
    }

    identitySubject.send(false)

    appUserId = try sanitize(userId: userId)
    await configManager.$config.hasValue()
    await configManager.getAssignments()

    identitySubject.send(true)
  }

  /// Create an account but don't wait for assignments before returning.
  ///
  /// - Throws: An error of type ``IdentityError``.
  func createAccount(userId: String) throws {
    guard appUserId == nil else {
      throw IdentityError.alreadyLoggedIn
    }
    identitySubject.send(false)

    appUserId = try sanitize(userId: userId)

    identitySubject.send(true)
  }

  /// Logs user out and calls ``Paywall/Paywall/reset()``
  ///
  /// - Throws: An ``IdentityError`` error, specifically ``IdentityError/notLoggedIn``
  /// if  the user isn't logged in.
  func logOut() async throws {
    if appUserId == nil {
      throw IdentityError.notLoggedIn
    }

    await Paywall.reset()
  }

  /// Clears all stored user-specific variables.
  func clear() {
    identitySubject.send(false)
    appUserId = nil
    aliasId = IdentityLogic.generateAlias()
    userAttributes = [:]
  }

  /// Merges the provided user attributes with existing attributes then saves them.
  func mergeUserAttributes(_ newUserAttributes: [String: Any]) {
    let mergedAttributes = IdentityLogic.mergeAttributes(
      newUserAttributes,
      with: userAttributes
    )
    storage.save(mergedAttributes, forType: UserAttributes.self)
    userAttributes = mergedAttributes
  }

  func resendIdentity() {
    let identityValue = identitySubject.value
    identitySubject.send(identityValue)
  }

  func forceHasIdentity() {
    identitySubject.send(true)
  }

  /// Removes white spaces and new lines
  ///
  /// - Throws: An ``IdentityError`` error, specifically ``IdentityError/missingAppUserId``
  /// if  the user isn't logged in.
  private func sanitize(userId: String) throws -> String {
    let userId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
    if userId.isEmpty {
      throw IdentityError.missingUserId
    }
    return userId
  }

  private func saveIds() {
    if let appUserId = appUserId {
      storage.save(appUserId, forType: AppUserId.self)
    }

    storage.save(aliasId, forType: AliasId.self)

    var newUserAttributes = [
      "aliasId": aliasId
    ]
    if let appUserId = appUserId {
      newUserAttributes["appUserId"] = appUserId
    }

    mergeUserAttributes(newUserAttributes)
  }
}
