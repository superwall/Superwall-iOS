//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/09/2022.
//

import Foundation
import Combine

//TODO: FILL OUT INFO HERE AND EXPLAIN ON LOGIN ETC THAT THIS IS THROWN
public enum IdentityError: Error {
  case configNotCalled
  case missingAppUserId
  case alreadyLoggedIn
  case notLoggedIn
}

final class IdentityManager {
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

  /// Logs user in and waits for config then assignments before firing triggers.
  func logIn(userId: String) async throws  {
    guard appUserId == nil else {
      throw IdentityError.alreadyLoggedIn
    }

    let userId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
    if userId.isEmpty {
      throw IdentityError.missingAppUserId
    }

    appUserId = userId

    try await configManager.$config
      .compactMap { $0 }
      .eraseToAnyPublisher()
      .async()
    await self.configManager.loadAssignments()

    // TODO: FIRE TRIGGERS AFTER THIS
  }

  func createAccount(userId: String) throws {
    guard appUserId == nil else {
      throw IdentityError.alreadyLoggedIn
    }

    let userId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
    if userId.isEmpty {
      throw IdentityError.missingAppUserId
    }

    appUserId = userId

    Task {
      await self.configManager.loadAssignments()
    }
  }

  func logOut() throws {
    if appUserId == nil {
      throw IdentityError.notLoggedIn
    }

    clear()
  }

  func clear() {
    appUserId = nil
    aliasId = IdentityLogic.generateAlias()
    userAttributes = [:]
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

    let mergedAttributes = IdentityLogic.mergeAttributes(
      newUserAttributes,
      with: userAttributes
    )
    storage.save(mergedAttributes, forType: UserAttributes.self)
    userAttributes = mergedAttributes
  }
/*


  func identify(with userId: String) {
    guard let outcome = StorageLogic.identify(
      newUserId: userId,
      oldUserId: appUserId
    ) else {
      loadAssignmentsIfNeeded()
      return
    }

    appUserId = userId

    switch outcome {
    case .reset:
      TriggerDelayManager.shared.appUserIdAfterReset = appUserId
      Paywall.reset()
    case .loadAssignments:
      if TriggerDelayManager.shared.appUserIdAfterReset == nil {
        loadAssignments()
      } else {
        loadAssignmentsAfterConfig(isBlocking: true)
        TriggerDelayManager.shared.appUserIdAfterReset = nil
      }
    }
  }
*/
}
