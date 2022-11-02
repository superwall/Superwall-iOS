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
  func test_migrateFromV1ToV2() {
    let cache = CacheMock()

    // Write all possible values to the cache.
    cache.write("userId", forType: AppUserId.self, inDirectory: .cache)
    cache.write("aliasId", forType: AliasId.self, inDirectory: .cache)
    cache.write(["a": "b"], forType: UserAttributes.self, inDirectory: .cache)
    cache.write(true, forType: DidTrackAppInstall.self, inDirectory: .cache)
    cache.write("true", forType: LegacyDidTrackFirstSeen.self)
    cache.write([.stub()], forType: TriggerSessions.self)
    cache.write([.stub()], forType: Transactions.self)

    // Check that they're in the cache and not in documents
    XCTAssertEqual(cache.internalCache.count, 7)
    XCTAssertEqual(cache.internalUserDocuments.count, 0)
    XCTAssertEqual(cache.internalAppDocuments.count, 0)

    // Migrate
    FileManagerMigrator.migrate(fromVersion: .v1, cache: cache)
    
    // Check they're all in the documents, except trigger sessions and transactions.
    XCTAssertEqual(cache.internalCache.count, 2)
    XCTAssertEqual(cache.internalAppDocuments.count, 2)
    XCTAssertEqual(cache.internalUserDocuments.count, 4)

    // Check that the old firstseen has gone
    let legacyFirstSeen = cache.read(LegacyDidTrackFirstSeen.self)
    XCTAssertNil(legacyFirstSeen)

    // Check new first seen exists and is a Bool
    let newFirstSeen = cache.read(DidTrackFirstSeen.self)!
    XCTAssertTrue(newFirstSeen)

    // Check the new version is v2
    let version = cache.read(Version.self)
    XCTAssertEqual(version, .v2)
  }
}
