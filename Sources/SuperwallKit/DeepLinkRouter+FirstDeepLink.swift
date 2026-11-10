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
  /// page that the first deep link belongs to.
  static let customProductPageIdAttributeKey = "customProductPageId"

  /// The user attribute key holding the name of that custom product page.
  static let customProductPageNameAttributeKey = "customProductPageName"

  /// Captures the first deep link received during the first app session
  /// as a user attribute.
  ///
  /// App Store custom product pages can each specify a deep link, which is
  /// delivered on the first app open after install. Storing it as a user
  /// attribute means campaign results can be broken down by custom product
  /// page. The deep link is also sent with enrichment, so the server can
  /// answer which page it belongs to.
  ///
  /// - Parameters:
  ///   - original: The deep link as the app received it.
  ///   - resolved: The deep link mapped from a Superwall app-link, if it was
  ///     one.
  func captureFirstSessionDeepLink(
    original: URL,
    resolved: URL
  ) {
    if !storage.recordFirstSessionDeepLink(original: original, resolved: resolved) {
      return
    }
    identityManager.mergeUserAttributes(
      Self.firstDeepLinkAttributes(url: resolved.absoluteString, page: nil)
    )
    let fetchEnrichment = self.fetchEnrichment
    Task {
      await fetchEnrichment()
    }
  }

  /// Captures a deep link that arrived before config did, which is routed
  /// once config arrives.
  ///
  /// Capturing it now lets it go out with the enrichment request that the
  /// first config fetch waits for, so the custom product page can be known
  /// before the first paywall's audience is chosen.
  func captureFirstSessionDeepLink(beforeRouting url: URL) {
    if url.isSuperwallReturnLink {
      return
    }
    if url.redeemableCode != nil {
      return
    }
    captureFirstSessionDeepLink(
      original: url,
      resolved: url.isSuperwallDeepLink ? url.superwallDeepLinkMappedURL : url
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
