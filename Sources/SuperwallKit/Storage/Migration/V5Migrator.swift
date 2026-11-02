//
//  V5Migrator.swift
//  SuperwallKit
//

import Foundation

/// Moves the Core Data store from the root of Application Support into its
/// own folder.
///
/// The version is only bumped once the move has worked. Until then the old
/// store keeps being used, so no placements are lost, and the move is tried
/// again on the next launch.
enum V5Migrator: Migratable {
  static func migrateToNextVersion(cache: Cache) {
    migrateToNextVersion(cache: cache, coreDataStoreLocation: .default)
  }

  static func migrateToNextVersion(
    cache: Cache,
    coreDataStoreLocation: CoreDataStoreLocation
  ) {
    if coreDataStoreLocation.moveLegacyStore() {
      cache.write(.v6, forType: Version.self)
    }
  }
}
