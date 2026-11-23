//
//  IdentityState+Storage.swift
//  SuperwallKit
//
//  Created by Superwall on 04/11/2026.
//

import Foundation

extension IdentityState {
  /// Builds the identity from storage, generating and saving any ids that
  /// are missing.
  static func load(
    from storage: Storage,
    appInstalledAtString: String
  ) -> IdentityState {
    var newIds: [String: Any?] = [:]

    let aliasId: String
    if let storedAliasId = storage.get(AliasId.self) {
      aliasId = storedAliasId
    } else {
      aliasId = IdentityLogic.generateAlias()
      storage.save(aliasId, forType: AliasId.self)
      newIds[IdentityState.Keys.aliasId] = aliasId
    }

    let seed: Int
    if let storedSeed = storage.get(Seed.self) {
      seed = storedSeed
    } else {
      seed = IdentityLogic.generateSeed()
      storage.save(seed, forType: Seed.self)
      newIds[IdentityState.Keys.seed] = seed
    }

    var userAttributes = storage.get(UserAttributes.self) ?? [:]
    var shouldSaveAttributes = false

    // Attributes used to be able to hold values that can't be represented
    // as JSON. Drop them once.
    if storage.get(DidCleanUserAttributes.self) != true {
      userAttributes = IdentityLogic.cleanedAttributes(userAttributes)
      storage.save(true, forType: DidCleanUserAttributes.self)
      shouldSaveAttributes = true
    }

    var state = IdentityState(
      appUserId: storage.get(AppUserId.self),
      aliasId: aliasId,
      seed: seed,
      userAttributes: userAttributes,
      appInstalledAtString: appInstalledAtString
    )

    if !newIds.isEmpty {
      state = state.merging(newIds)
      shouldSaveAttributes = true
    }

    if shouldSaveAttributes {
      storage.save(state.userAttributes, forType: UserAttributes.self)
    }

    return state
  }
}
