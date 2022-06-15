//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/06/2022.
//

import Foundation

protocol Migratable {
  static func migrateToNextVersion(cache: Cache)
}

enum LegacyDidTrackFirstSeen: Storable {
  static var key: String {
    "store.didTrackFirstSeen"
  }
  static var directory: SearchPathDirectory = .cache
  // This gets migrated to a Bool in v2.
  typealias Value = String
}

enum V1Migrator: Migratable {
  static func migrateToNextVersion(
    cache: Cache
  ) {
    // Check directory for each item. If data exists but in wrong directory, move.
    moveFromCacheDirectory(
      AppUserId.self,
      cache: cache
    )
    moveFromCacheDirectory(
      AliasId.self,
      cache: cache
    )
    moveFromCacheDirectory(
      UserAttributes.self,
      cache: cache
    )
    moveFromCacheDirectory(
      DidTrackAppInstall.self,
      cache: cache
    )
    moveFromCacheDirectory(
      TriggeredEvents.self,
      cache: cache
    )

    // Convert DidTrackFirstSeen to a bool and move from cache to documents directory
    if let data = cache.read(LegacyDidTrackFirstSeen.self) {
      let boolValue = (data as NSString).boolValue
      cache.write(boolValue, forType: DidTrackFirstSeen.self)
      cache.delete(LegacyDidTrackFirstSeen.self, fromDirectory: .cache)
    }

    cache.write(.v2, forType: Version.self)
  }

  static private func moveFromCacheDirectory<T: Storable>(
    _ type: T.Type,
    cache: Cache
  ) {
    if let data = cache.read(
      type.self,
      fromDirectory: .cache
    ) {
      cache.delete(type.self, fromDirectory: .cache)
      cache.write(data, forType: type.self)
    }
  }

  static private func moveFromCacheDirectory<T>(
    _ type: T.Type,
    cache: Cache
  ) where T: Storable, T.Value: Codable {
    if let data = cache.read(
      type.self,
      fromDirectory: .cache
    ) {
      cache.delete(type.self, fromDirectory: .cache)
      cache.write(data, forType: type.self)
    }
  }
}
