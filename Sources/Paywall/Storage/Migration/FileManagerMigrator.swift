//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/06/2022.
//

import Foundation

enum FileManagerMigrator {
  enum Version: Int, CaseIterable {
    case v1
    case v2
  }

  static func migrate(fromVersion version: Version) {
    let rawCurrentVersion = version.rawValue
    let rawMaxVersion = Version.allCases.count

    if rawCurrentVersion == rawMaxVersion {
      return
    }



    for rawVersion in rawCurrentVersion..<rawMaxVersion {

    }
  }

  private static func migrate(
    fromVersion: Version,
    to toVersion: Version
  ) {
    // Take
  }

  func versionOneToTwoMigrator() {
    Storage.shared.
  }
}
