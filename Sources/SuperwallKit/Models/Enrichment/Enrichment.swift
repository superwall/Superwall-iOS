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
}

/// Request-only context is never cached as part of the enrichment response.
struct EnrichmentRequest: Encodable {
  struct DeepLink: Encodable, Equatable {
    /// The URL delivered by the app, before Superwall rewrites an app-link URL.
    let originalURL: URL
    /// The destination used by deepLink_open and placement rules.
    let resolvedURL: URL
  }

  let user: JSON
  let device: JSON
  var deepLink: DeepLink?
}
