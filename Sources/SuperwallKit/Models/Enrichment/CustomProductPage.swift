//
//  CustomProductPage.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 06/11/2026.
//

import Foundation

/// The App Store custom product page that the first deep link belongs to.
///
/// The app is only given the deep link, never the page's ID, so the server
/// looks the page up from the deep links set in App Store Connect and sends it
/// back with enrichment.
struct CustomProductPage: Codable, Equatable {
  /// The page's ID in App Store Connect, the `ppid` in its App Store URL.
  let id: String

  /// The page's name in App Store Connect.
  let name: String?

  init(
    id: String,
    name: String?
  ) {
    self.id = id
    self.name = name
  }

  /// The page in the user attributes of an enrichment response, if the server
  /// found one.
  init?(userAttributes: JSON) {
    guard
      let id = userAttributes[DeepLinkRouter.customProductPageIdAttributeKey].string,
      !id.isEmpty
    else {
      return nil
    }
    self.id = id
    self.name = userAttributes[DeepLinkRouter.customProductPageNameAttributeKey].string
  }
}
