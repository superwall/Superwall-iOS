//
//  PaywallCacheLogic.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//

import Foundation

enum PaywallCacheLogic: Sendable {
  static func key(
    forIdentifier identifier: String?,
    locale: String
  ) -> String {
    let id = identifier ?? "$no_id"
    return "\(id)_\(locale)"
  }
}
