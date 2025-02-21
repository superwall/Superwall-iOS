//
//  File.swift
//  
//
//  Created by Yusuf Tör on 14/06/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

final class FileManagerMigratorTests: XCTestCase {
  func test_migrateFromV1ToV3() {
    let cache = CacheMock()

    // Write all possible values to the cache.
    cache.write("userId", forType: AppUserId.self, inDirectory: .cache)
    cache.write("aliasId", forType: AliasId.self, inDirectory: .cache)
    cache.write(["a": "b"], forType: UserAttributes.self, inDirectory: .cache)
    cache.write(true, forType: DidTrackAppInstall.self, inDirectory: .cache)
    cache.write("true", forType: LegacyDidTrackFirstSeen.self)

    let experimentId = "abc"
    let variant = Experiment.Variant(id: "1", type: .treatment, paywallId: "def")
    cache.write([experimentId: variant], forType: LegacyConfirmedAssignments.self)
    cache.write([.stub()], forType: Transactions.self)

    // Check that they're in the cache and not in documents
    XCTAssertEqual(cache.internalCache.count, 6)
    XCTAssertEqual(cache.internalUserDocuments.count, 1)
    XCTAssertEqual(cache.internalAppDocuments.count, 0)

    // Migrate
    FileManagerMigrator.migrate(fromVersion: .v1, cache: cache)
    
    // Check they're all in the documents, except transactions.
    XCTAssertEqual(cache.internalCache.count, 1)
    XCTAssertEqual(cache.internalAppDocuments.count, 2)
    XCTAssertEqual(cache.internalUserDocuments.count, 5)

    // Check that the old firstseen has gone
    let legacyFirstSeen = cache.read(LegacyDidTrackFirstSeen.self)
    XCTAssertNil(legacyFirstSeen)

    // Check new first seen exists and is a Bool
    let newFirstSeen = cache.read(DidTrackFirstSeen.self)!
    XCTAssertTrue(newFirstSeen)

    // Check that the old confirmed assignments has gone
    let legacyAssignments = cache.read(LegacyConfirmedAssignments.self)
    XCTAssertNil(legacyAssignments)

    // Check new first seen exists and is a Bool
    let newAssignments = cache.read(Assignments.self)!
    XCTAssertEqual(newAssignments.first!.experimentId, experimentId)
    XCTAssertEqual(newAssignments.first!.variant, variant)

    // Check the new version is v3
    let version = cache.read(Version.self)
    XCTAssertEqual(version, .v3)
  }
}
