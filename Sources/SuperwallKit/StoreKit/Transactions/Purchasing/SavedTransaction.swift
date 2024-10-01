//
//  SavedTransaction.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 01/10/2024.
//

import Foundation

/// The transaction to save to storage.
struct SavedTransaction: Codable, Hashable {
  /// The transaction id.
  let id: String

  /// The date the transaction was created.
  let date: Date

  /// Whether or not the developer is using a purchase controller.
  let hasExternalPurchaseController: Bool

  /// Indicates whether the purchase was initiated externally via the
  /// developer rather than internally via the SDK.
  let isExternal: Bool
}
