//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 17/02/2025.
//

import Foundation

enum LegacyConfirmedAssignments: Storable {
  static var key: String {
    "store.confirmedAssignments"
  }
  static var directory: SearchPathDirectory = .userSpecificDocuments
  typealias Value = [Experiment.ID: Experiment.Variant]
}

/// Moves data between different directories rather than all in the cache.
enum V2Migrator: Migratable {
  static func migrateToNextVersion(cache: Cache) {
    cache.moveDataFromDocumentsToApplicationSupport()

    // Migrate confirmed assignments to a type that includes whether the confirmation has
    // been sent to the server or not. The old ones are always true.
    if let oldValue = cache.read(LegacyConfirmedAssignments.self) {
      var assignments: Set<Assignment> = []
      for (id, variant) in oldValue {
        assignments.insert(
          Assignment(
            experimentId: id,
            variant: variant,
            isSentToServer: true
          )
        )
      }
      cache.write(assignments, forType: Assignments.self)
      cache.delete(LegacyConfirmedAssignments.self)
    }

    cache.write(.v3, forType: Version.self)
  }
}
