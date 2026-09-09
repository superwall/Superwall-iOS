//
//  DevServerSurface.swift
//  SuperwallKit
//
//  One entry in the surface list a running `superwall dev` server exposes:
//  a locally served paywall or funnel, and the dashboard paywall it is
//  bound to via `superwall.lock`, if any.
//
//  The manifest carries identity, products, and the settings the surface's
//  config.ts declares. Anything it leaves out — intro offer eligibility,
//  computed properties, surveys — reaches the SDK only in the pushed
//  snapshot, so those come from the published paywall the surface stands in
//  for.
//

import Foundation

struct DevServerSurface: Decodable, Equatable {
  let kind: String
  let id: String
  let url: String

  /// The dashboard paywall this surface is bound to via `superwall.lock`.
  let paywallId: String?

  /// Every paywall this surface is bound to, when the lock binds it to more
  /// than one. The CLI sends the first as `paywallId` and the full set here.
  let paywallIds: [String]?

  let identifier: String?
  let products: [String: String]?

  /// What the surface's `config.ts` says about presenting it. Absent from a
  /// dev server older than the settings block, in which case the published
  /// paywall's settings stand.
  let settings: DevServerSettings?

  private enum CodingKeys: String, CodingKey {
    case kind
    case id
    case url
    case paywallId
    case paywallIds
    case identifier
    case products
    case settings
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    kind = try container.decode(String.self, forKey: .kind)
    id = try container.decode(String.self, forKey: .id)
    url = try container.decode(String.self, forKey: .url)
    paywallId = try container.decodeIfPresent(String.self, forKey: .paywallId)
    paywallIds = try container.decodeIfPresent([String].self, forKey: .paywallIds)
    identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
    products = try container.decodeIfPresent([String: String].self, forKey: .products)
    settings = try? container.decodeIfPresent(DevServerSettings.self, forKey: .settings)
  }
}
