//
//  CacheKeys+FirstDeepLink.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 10/11/2026.
//

import Foundation

/// The first deep link of the first app session, kept until the server has
/// answered which custom product page it belongs to.
enum FirstSessionDeepLinkLookup: Storable {
  static var key: String {
    "store.firstSessionDeepLinkLookup"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = EnrichmentDeepLink
}

/// The custom product page that ``FirstSessionDeepLinkURL`` belongs to.
enum FirstSessionCustomProductPage: Storable {
  static var key: String {
    "store.firstSessionCustomProductPage"
  }
  static var directory: SearchPathDirectory = .appSpecificDocuments
  typealias Value = CustomProductPage
}
