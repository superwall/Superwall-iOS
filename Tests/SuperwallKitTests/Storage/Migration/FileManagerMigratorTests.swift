//
//  File.swift
//
//
//  Created by Yusuf Tör on 14/06/2022.
//
// swiftlint:disable all

import Testing
import Foundation
@testable import SuperwallKit

struct FileManagerMigratorTests {
  @Test
  func migrateFromV1ToV4() {
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
    #expect(cache.internalCache.count == 6)
    #expect(cache.internalUserDocuments.count == 1)
    #expect(cache.internalAppDocuments.count == 0)

    // Migrate
    FileManagerMigrator.migrate(fromVersion: .v1, cache: cache)

    // Check they're all in the documents, except transactions.
    #expect(cache.internalCache.count == 1)
    #expect(cache.internalAppDocuments.count == 2)
    #expect(cache.internalUserDocuments.count == 5)

    // Check that the old firstseen has gone
    let legacyFirstSeen = cache.read(LegacyDidTrackFirstSeen.self)
    #expect(legacyFirstSeen == nil)

    // Check new first seen exists and is a Bool
    let newFirstSeen = cache.read(DidTrackFirstSeen.self)
    #expect(newFirstSeen == true)

    // Check that the old confirmed assignments has gone
    let legacyAssignments = cache.read(LegacyConfirmedAssignments.self)
    #expect(legacyAssignments == nil)

    // Check new assignments exists
    let newAssignments = cache.read(Assignments.self)
    #expect(newAssignments?.first?.experimentId == experimentId)
    #expect(newAssignments?.first?.variant == variant)

    // Check the new version is v4
    let version = cache.read(Version.self)
    #expect(version == .v4)
  }

  @Test
  func migrateRedeemResponseFromV3ToV4() {
    let cache = CacheMock()

    // Create old RedeemResponse with legacy entitlements
    let entitlement1 = LegacyEntitlement(
      id: "ent1",
      type: .serviceLevel
    )
    let entitlement2 = LegacyEntitlement(
      id: "ent2",
      type: .serviceLevel
    )
    let redemptionResult = RedemptionResult.invalidCode(code: "test-code")

    let oldRedeemResponse = LegacyRedeemResponse(
      results: [redemptionResult],
      entitlements: Set([entitlement1, entitlement2])
    )

    // Write old RedeemResponse to cache
    cache.write(oldRedeemResponse, forType: LegacyLatestRedeemResponse.self)
    cache.write(.v3, forType: Version.self)

    // Verify old data exists before migration
    let oldData = cache.read(LegacyLatestRedeemResponse.self)
    #expect(oldData != nil, "Old data should exist before migration")
    #expect(oldData?.entitlements.count == 2, "Should have 2 entitlements before migration")

    // Migrate
    V3Migrator.migrateToNextVersion(cache: cache)

    // Check new RedeemResponse exists with CustomerInfo
    // Note: The legacy data is overwritten with the new format at the same key
    let newRedeemResponse = cache.read(LatestRedeemResponse.self)
    #expect(newRedeemResponse != nil, "New RedeemResponse should exist after migration")

    if let newRedeemResponse = newRedeemResponse {
      #expect(newRedeemResponse.results.count == 1)
      #expect(newRedeemResponse.results.first?.code == "test-code")

      // Check CustomerInfo has the entitlements
      #expect(newRedeemResponse.customerInfo.entitlements.count == 2)
      #expect(newRedeemResponse.customerInfo.subscriptions.count == 0)
      #expect(newRedeemResponse.customerInfo.nonSubscriptions.count == 0)

      // Verify entitlements were preserved
      let entitlementIds = Set(newRedeemResponse.customerInfo.entitlements.map { $0.id })
      #expect(entitlementIds.contains("ent1"))
      #expect(entitlementIds.contains("ent2"))
    }

    // Check the new version is v4
    let version = cache.read(Version.self)
    #expect(version == .v4)
  }
}
