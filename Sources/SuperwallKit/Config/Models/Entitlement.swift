//
//  File.swift
//  
//
//  Created by Yusuf Tör on 19/12/2022.
//

import Foundation

/// A subscription level that a user can be subscribed to. A user can
/// have multiple entitlements.
struct Entitlement: Codable, Hashable {
  /// The entitlement id.
  let id: String

  /// The name of the entitlement, e.g. "pro"
  let name: String

  /// The ids of the products that belong to the entitlement.
  let productIds: Set<String>

  static func blank(withName name: String) -> Entitlement {
    return Entitlement(
      id: UUID().uuidString,
      name: name,
      productIds: []
    )
  }
}
