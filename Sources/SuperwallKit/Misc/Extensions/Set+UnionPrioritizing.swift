//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 20/03/2025.
//

import Foundation

extension Set where Element == Entitlement {
  func unionCombiningSources(_ other: Set<Entitlement>) -> Set<Entitlement> {
    var entitlementMap: [String: Entitlement] = [:]

    // Insert all entitlements from self
    for entitlement in self {
      entitlementMap[entitlement.id] = entitlement
    }

    // Insert from other, prioritizing .device
    for entitlement in other {
      let key = entitlement.id
      if let existing = entitlementMap[key] {
        let combinedSource = existing.source.union(entitlement.source)
        let combined = Entitlement(
          id: existing.id,
          type: existing.type,
          source: combinedSource
        )
        entitlementMap[key] = combined
      } else {
        entitlementMap[key] = entitlement
      }
    }

    return Set(entitlementMap.values)
  }
}
