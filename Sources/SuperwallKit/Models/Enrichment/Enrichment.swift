//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 10/04/2025.
//

import Foundation

struct Enrichment: Codable {
  let user: JSON
  let device: JSON

  /// The server's answer about the request's deep link. `nil` when the request
  /// had none, or when the server couldn't look it up yet.
  var deepLink: EnrichmentDeepLinkAnswer?
}

/// The body of an enrichment request.
struct EnrichmentRequest: Encodable {
  let user: JSON
  let device: JSON

  /// The first deep link of the first app session, sent until the server has
  /// answered which App Store custom product page it belongs to.
  var deepLink: EnrichmentDeepLink?
}

/// A deep link as the app received it, and as Superwall routes it.
struct EnrichmentDeepLink: Codable, Equatable {
  /// The URL passed to `Superwall.handleDeepLink`.
  let originalUrl: String

  /// The URL after mapping a Superwall app-link. The same as ``originalUrl``
  /// for any other deep link.
  let resolvedUrl: String
}

/// Whether the server found the custom product page a deep link belongs to.
struct EnrichmentDeepLinkAnswer: Codable, Equatable {
  let matched: Bool
}
