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
  var identityPublisher = PassthroughSubject<Void, Never>()
  private let storage: Storage
  private let configManager: ConfigManager
  private var cancellables: Set<AnyCancellable> = []

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

  func configure() async {
    await configManager.$config.value()

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
    identityPublisher.send(completion: .finished)
  }

  // TODO: What happens if they have more than one device?

  // TODO: Run through static config and whether we need to block due to that. Always refer to version of storage file on master.


  /// Logs user in and waits for config then assignments before firing triggers.
  func logIn(userId: String) async throws  {
    guard appUserId == nil else {
      throw IdentityError.alreadyLoggedIn
    }

    appUserId = try sanitize(userId: userId)

    await configManager.$config.value()
    await configManager.getAssignments()
    identityPublisher.send(completion: .finished)
  }

  func createAccount(userId: String) throws {
    guard appUserId == nil else {
      throw IdentityError.alreadyLoggedIn
    }

    appUserId = try sanitize(userId: userId)

    Task {
      await self.configManager.getAssignments()
    }
    identityPublisher.send(completion: .finished)
  }

  func logOut() async throws {
    if appUserId == nil {
      throw IdentityError.notLoggedIn
    }

    await Paywall.reset()
  }

  func clear() {
    appUserId = nil
    aliasId = IdentityLogic.generateAlias()
    userAttributes = [:]
  }

  func mergeUserAttributes(_ newUserAttributes: [String: Any]) {
    let mergedAttributes = IdentityLogic.mergeAttributes(
      newUserAttributes,
      with: userAttributes
    )
    storage.save(mergedAttributes, forType: UserAttributes.self)
    userAttributes = mergedAttributes
  }

  private func sanitize(userId: String) throws -> String {
    let userId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
    if userId.isEmpty {
      throw IdentityError.missingAppUserId
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
