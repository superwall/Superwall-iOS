//
//  PaywallSummary.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 30/07/2026.
//

import Foundation

/// The minimal paywall metadata the debug/preview flow needs: enough to fetch
/// and label a paywall.
struct PaywallSummary: Decodable {
  /// The id of the paywall in the database.
  let id: String

  /// The identifier (slug) of the paywall, used to fetch the full paywall.
  let identifier: String

  /// The display name of the paywall.
  let name: String
}
