//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/09/2022.
//

import Foundation
import Combine

class IdentityManager {
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
  var isLoggedIn: Bool {
    return appUserId != nil
  }

  /// Indicates whether the identity (i.e. anonymous or logged in with
  /// assignments) has been retrieved.
  ///
  /// When `false`, the SDK is unable to present paywalls.
  private var identitySubject = CurrentValueSubject<Bool, Never>(false)

  /// A Publisher that only emits when `identitySubject` is `true`. When `true`,
  /// it means the SDK is ready to fire triggers.
  var hasIdentity: AnyPublisher<Bool, Error> {
    identitySubject
      .filter { $0 == true }
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }

  private unowned let deviceHelper: DeviceHelper
  private unowned let storage: Storage
  private unowned let configManager: ConfigManager

  /// Only use init for testing purposes. Otherwise use `shared`.
  init(
    deviceHelper: DeviceHelper,
    storage: Storage,
    configManager: ConfigManager
  ) {
    self.deviceHelper = deviceHelper
    self.storage = storage
    self.configManager = configManager
    self.appUserId = storage.get(AppUserId.self)
    self.aliasId = storage.get(AliasId.self) ?? IdentityLogic.generateAlias()
    self.userAttributes = storage.get(UserAttributes.self) ?? [:]
  }

  /// Waits for config to return before getting assignments (if needed).
  func configure() async {
    await configManager.$config.hasValue()

    let accountExistedPreStaticConfig = storage.neverCalledStaticConfig
    let isFirstAppOpen = !(storage.get(DidTrackFirstSeen.self) ?? false)

    if IdentityLogic.shouldGetAssignments(
      isLoggedIn: isLoggedIn,
      accountExistedPreStaticConfig: accountExistedPreStaticConfig,
      isFirstAppOpen: isFirstAppOpen
    ) {
      await configManager.getAssignments()
    }

    didSetIdentity()
  }

  /// Logs user in and waits for config then assignments.
  ///
  /// - Throws: An error of type ``IdentityError``.
  func logIn(userId: String) async throws {
    guard appUserId == nil else {
      throw IdentityError.alreadyLoggedIn
    }

    identitySubject.send(false)

    guard let appUserId = sanitize(userId: userId) else {
      throw IdentityError.missingUserId
    }
    self.appUserId = appUserId

    await configManager.$config.hasValue()
    await configManager.getAssignments()

    didSetIdentity()
  }

  /// Create an account but don't wait for assignments before returning.
  ///
  /// - Throws: An error of type ``IdentityError``.
  func createAccount(userId: String) throws {
    guard appUserId == nil else {
      throw IdentityError.alreadyLoggedIn
    }
    identitySubject.send(false)

    guard let appUserId = sanitize(userId: userId) else {
      throw IdentityError.missingUserId
    }
    self.appUserId = appUserId

    didSetIdentity()
  }

  /// Logs user out and calls ``SuperwallKit/Superwall/reset()``
  ///
  /// - Throws: An error of type``LogoutError``.
  /// if  the user isn't logged in.
  func logOut() async throws {
    if appUserId == nil {
      throw LogoutError.notLoggedIn
    }

    await Superwall.reset()
  }

  /// Clears all stored user-specific variables.
  func reset() {
    identitySubject.send(false)
    appUserId = nil
    aliasId = IdentityLogic.generateAlias()
    userAttributes = [:]
  }

  /// Merges the provided user attributes with existing attributes then saves them.
  func mergeUserAttributes(_ newUserAttributes: [String: Any]) {
    let mergedAttributes = IdentityLogic.mergeAttributes(
      newUserAttributes,
      with: userAttributes,
      appInstalledAtString: deviceHelper.appInstalledAtString
    )
    storage.save(mergedAttributes, forType: UserAttributes.self)
    userAttributes = mergedAttributes
  }

  /// Resends the last stored value of the `identitySubject`.
  ///
  /// Used to present a paywall again.
  func resendIdentity() {
    let identityValue = identitySubject.value
    identitySubject.send(identityValue)
  }

  /// Sends a `true` value to the `identitySubject` in order to fire
  /// triggers after reset.
  func didSetIdentity() {
    identitySubject.send(true)
  }

  /// Removes white spaces and new lines
  ///
  /// - Returns: An optional `String` of the trimmed `userId`. This is `nil`
  /// if the `userId` is empty.
  private func sanitize(userId: String) -> String? {
    let userId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
    if userId.isEmpty {
      return nil
    }
    return userId
  }

  /// Saves the aliasId and appUserId to storage and user attributes.
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
