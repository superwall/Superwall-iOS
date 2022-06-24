//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/06/2022.
//
// swiftlint:disable identifier_name

import Foundation

enum DataStoreVersion: Int, CaseIterable, Codable {
  case v1
  case v2
}

enum FileManagerMigrator {
  static func migrate(
    fromVersion version: DataStoreVersion,
    cache: Cache
  ) {
    let rawCurrentVersion = version.rawValue
    let rawMaxVersion = DataStoreVersion.allCases.count - 1

    if rawCurrentVersion == rawMaxVersion {
      return
    }

    switch version {
    case .v1:
      V1Migrator.migrateToNextVersion(cache: cache)
    case .v2:
      break
    }

    let newRawVersion = rawCurrentVersion + 1
    guard let newVersion = DataStoreVersion(rawValue: newRawVersion) else {
      return
    }

    migrate(
      fromVersion: newVersion,
      cache: cache
    )
  }
}
