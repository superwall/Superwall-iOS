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
  ///   - fetchesEnrichment: Whether to fetch enrichment for it now. `false`
  ///     when a fetch that will carry it is about to start.
  func captureFirstSessionDeepLink(
    original: URL,
    resolved: URL,
    fetchesEnrichment: Bool = true
  ) {
    if !storage.recordFirstSessionDeepLink(original: original, resolved: resolved) {
      return
    }
    identityManager.mergeUserAttributes(
      Self.firstDeepLinkAttributes(url: resolved.absoluteString, page: nil)
    )
    if !fetchesEnrichment {
      return
    }
    let fetchEnrichment = self.fetchEnrichment
    Task {
      await fetchEnrichment()
    }
  }

  /// Captures the deep link waiting to be routed, if the app received one
  /// before it configured the SDK, as the SDK starts up.
  ///
  /// Called before the first config fetch, whose enrichment request then
  /// carries it. Left until the link is routed, it would only be looked up
  /// after that request, and the first paywall's audience could be chosen
  /// without its custom product page.
  func captureFirstSessionDeepLinkReceivedBeforeConfigure() {
    captureFirstSessionDeepLink(receivedBeforeConfigure: Self.pendingDeepLink)
  }

  func captureFirstSessionDeepLink(receivedBeforeConfigure url: URL?) {
    guard let url else {
      return
    }
    captureEligibleFirstSessionDeepLink(url, fetchesEnrichment: false)
  }

  /// Captures a deep link that arrived before config did, which is routed
  /// once config arrives.
  ///
  /// Capturing it now lets it go out with the enrichment request that the
  /// first config fetch waits for, so the custom product page can be known
  /// before the first paywall's audience is chosen.
  ///
  /// - Parameters:
  ///   - url: The deep link that just arrived.
  ///   - earlierUrl: A deep link still waiting to be routed, which arrived
  ///     before this one, such as one received before the SDK was configured.
  ///     It's captured first.
  func captureFirstSessionDeepLink(
    beforeRouting url: URL,
    after earlierUrl: URL? = nil
  ) {
    if let earlierUrl {
      captureEligibleFirstSessionDeepLink(earlierUrl)
    }
    captureEligibleFirstSessionDeepLink(url)
  }

  private func captureEligibleFirstSessionDeepLink(_ url: URL, fetchesEnrichment: Bool = true) {
    if url.isSuperwallReturnLink {
      return
    }
    if url.redeemableCode != nil {
      return
    }
    captureFirstSessionDeepLink(
      original: url,
      resolved: url.isSuperwallDeepLink ? url.superwallDeepLinkMappedURL : url,
      fetchesEnrichment: fetchesEnrichment
    )
  }

  /// Asks again which custom product page the first deep link belongs to, if
  /// the server hasn't answered yet. Called once the config is in.
  ///
  /// A link captured at startup has no fetch of its own, and the config
  /// fetch's enrichment request is one short try that may not get through.
  func fetchEnrichmentIfFirstDeepLinkIsUnanswered() {
    if storage.get(FirstSessionDeepLinkLookup.self) == nil {
      return
    }
    let fetchEnrichment = self.fetchEnrichment
    Task {
      await fetchEnrichment()
    }
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
