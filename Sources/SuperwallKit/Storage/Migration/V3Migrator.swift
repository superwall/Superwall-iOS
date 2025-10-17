//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 03/10/2025.
//

import Foundation

/// The old Entitlement structure before additional fields were added
struct LegacyEntitlement: Codable, Hashable {
  let id: String
  let type: EntitlementType

  private enum CodingKeys: String, CodingKey {
    case id = "identifier"
    case type
  }

  func toNew() -> Entitlement {
    return Entitlement(
      id: id,
      type: type,
      isActive: true,
      productIds: [],
      latestProductId: nil,
      store: .stripe
    )
  }
}

struct LegacyRedeemResponse: Codable {
  var results: [RedemptionResult]
  var entitlements: Set<LegacyEntitlement>

  private enum CodingKeys: String, CodingKey {
    case results = "codes"
    case entitlements
  }

  var allCodes: Set<Redeemable> {
    return Set(results.map {
      Redeemable(code: $0.code, isFirstRedemption: false)
    })
  }

  init(
    results: [RedemptionResult],
    entitlements: Set<LegacyEntitlement>
  ) {
    self.results = results
    self.entitlements = entitlements
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.results = try container.decode([RedemptionResult].self, forKey: .results)
    self.entitlements = try container.decode(Set<LegacyEntitlement>.self, forKey: .entitlements)
  }
}

enum LegacyLatestRedeemResponse: Storable {
  static var key: String {
    // Using the same key as the current version because we're migrating from the old format
    // The old data will be decoded as LegacyRedeemResponse, then converted and written
    // back as the new RedeemResponse format
    "store.latestRedeemResponse"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = LegacyRedeemResponse
}

/// Migrates RedeemResponse from old structure with entitlements to new structure with customerInfo.
enum V3Migrator: Migratable {
  static func migrateToNextVersion(cache: Cache) {
    // Migrate RedeemResponse from old structure with entitlements to new structure with customerInfo
    if let oldRedeemResponse = cache.read(LegacyLatestRedeemResponse.self) {
      // Convert legacy entitlements to new entitlements
      let newEntitlements = oldRedeemResponse.entitlements.map { $0.toNew() }

      let newRedeemResponse = RedeemResponse(
        results: oldRedeemResponse.results,
        customerInfo: CustomerInfo(
          subscriptions: [],
          nonSubscriptions: [],
          entitlements: newEntitlements
        )
      )
      // Write the new format - this overwrites the old data at the same key
      cache.write(newRedeemResponse, forType: LatestRedeemResponse.self)
      // No need to delete since we're using the same key and just overwrote it
    }

    cache.write(.v4, forType: Version.self)
  }
}
