//
//  DeepLinkRouter+FirstDeepLink.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 06/11/2026.
//

import Foundation

extension DeepLinkRouter {
  /// The user attribute key holding the first deep link URL received
  /// during the first app session after install.
  static let firstDeepLinkUrlAttributeKey = "firstDeepLinkUrl"

  /// The user attribute key holding the ID of the App Store custom product
  /// page whose deep link was the first deep link.
  static let customProductPageIdAttributeKey = "customProductPageId"

  /// The user attribute key holding the name of that custom product page.
  static let customProductPageNameAttributeKey = "customProductPageName"

  /// Captures the first deep link received during the first app session
  /// as a user attribute.
  ///
  /// App Store custom product pages can each specify a deep link, which is
  /// delivered on the first app open after install. Storing it as a user
  /// attribute means campaign results can be broken down by custom product
  /// page. When the config lists the app's custom product pages, the page
  /// the deep link belongs to is saved too.
  ///
  /// - Parameters:
  ///   - url: The deep link, mapped from a Superwall app-link if it was one.
  ///   - originalUrl: The deep link as the app received it. A custom product
  ///     page's deep link can be a Superwall app-link, so both are matched.
  func captureFirstSessionDeepLink(_ url: URL, originalUrl: URL) {
    if !storage.recordFirstSessionDeepLink(url) {
      return
    }
    let page = CustomProductPage.matching(
      [url, originalUrl],
      in: configManager.config?.customProductPages ?? []
    )
    if let page {
      storage.save(page, forType: FirstSessionCustomProductPage.self)
    }
    identityManager.mergeUserAttributes(
      Self.firstDeepLinkAttributes(url: url.absoluteString, page: page)
    )
  }

  /// The first deep link's user attributes, which a new user keeps across a
  /// reset because they describe the install.
  func firstDeepLinkAttributesKeptAcrossReset() -> [String: Any] {
    guard let url = storage.get(FirstSessionDeepLinkURL.self) else {
      return [:]
    }
    return Self.firstDeepLinkAttributes(
      url: url,
      page: storage.get(FirstSessionCustomProductPage.self)
    )
  }

  private static func firstDeepLinkAttributes(
    url: String,
    page: CustomProductPage?
  ) -> [String: Any] {
    var attributes: [String: Any] = [firstDeepLinkUrlAttributeKey: url]
    if let page {
      attributes[customProductPageIdAttributeKey] = page.id
      attributes[customProductPageNameAttributeKey] = page.name
    }
    return attributes
  }
}
