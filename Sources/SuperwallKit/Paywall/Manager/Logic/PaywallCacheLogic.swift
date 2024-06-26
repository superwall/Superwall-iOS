//
//  PaywallCacheLogic.swift
//  
//
//  Created by Yusuf Tör on 09/03/2022.
//

import Foundation

enum PaywallCacheLogic: Sendable {
  static func key(
    identifier: String,
    locale: String
  ) -> String {
    return "\(identifier)_\(locale)"
  }
}
