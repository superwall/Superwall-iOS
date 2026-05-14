//
//  V4Migrator.swift
//  SuperwallKit
//

import Foundation

/// Pre-v5, the AdServices token sentinel lived in `.userSpecificDocuments` —
/// it was scoped per-user so that `reset(duringIdentify:)` would wipe it and a
/// new user could re-fetch. Apple Search Ads attribution is install-scoped
/// (the campaign that drove the install doesn't change with who's logged in),
/// so as of v5 the sentinel lives in `.appSpecificDocuments` and survives
/// `reset`. This shim reads from the legacy directory during migration.
enum LegacyUserScopedAdServicesTokenStorage: Storable {
  static var key: String {
    // Same key string as AdServicesTokenStorage — only the directory differs.
    "store.adServicesToken"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = String
}

/// Migrates the AdServices token sentinel from user-specific to app-specific
/// storage so existing attributed users aren't seen as "never attributed"
/// after upgrade and re-attempted.
enum V4Migrator: Migratable {
  static func migrateToNextVersion(cache: Cache) {
    if cache.read(AdServicesTokenStorage.self) == nil,
      let legacyToken = cache.read(LegacyUserScopedAdServicesTokenStorage.self) {
      cache.write(legacyToken, forType: AdServicesTokenStorage.self)
      cache.delete(LegacyUserScopedAdServicesTokenStorage.self, fromDirectory: .userSpecificDocuments)
    }

    cache.write(.v5, forType: Version.self)
  }
}
