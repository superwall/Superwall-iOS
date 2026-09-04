//
//  DevServerSurface.swift
//  SuperwallKit
//
//  One entry in the surface list a running `superwall dev` server exposes:
//  a locally served paywall or funnel, and the dashboard paywall it is
//  bound to via `superwall.lock`, if any.
//

import Foundation

struct DevServerSurface: Decodable, Equatable {
  /// How the paywall asks to be presented, straight from its `config.ts`.
  ///
  /// The geometry is optional throughout: a `config.ts` may set only some of
  /// it, and the CLI that writes this manifest versions separately from the
  /// SDK, so a block the SDK can't fully read still presents.
  struct Presentation: Decodable, Equatable {
    struct Drawer: Decodable, Equatable {
      let height: Double?
      let cornerRadius: Double?
    }
    struct Popup: Decodable, Equatable {
      let width: Double?
      let height: Double?
      let cornerRadius: Double?
    }

    let style: String?
    let drawer: Drawer?
    let popup: Popup?
  }

  let kind: String
  let id: String
  let url: String
  let paywallId: String?

  /// Every dashboard paywall this surface is bound to, when `superwall.lock`
  /// binds it to more than one. The CLI sends `paywallId` for the first and
  /// this for the full set.
  let paywallIds: [String]?
  let identifier: String?
  let products: [String: String]?
  let presentation: Presentation?

  /// `config.ts` feature gating: "gated" or "nonGated".
  ///
  /// Kept as the raw string so a value this SDK doesn't recognise falls back
  /// to the published paywall's setting instead of failing the surface.
  let featureGating: String?

  /// `config.ts` trial eligibility: "automatic", "alwaysEligible" or
  /// "alwaysIneligible". Raw for the same reason as `featureGating`.
  let introductoryOfferEligibility: String?

  private enum CodingKeys: String, CodingKey {
    case kind
    case id
    case url
    case paywallId
    case paywallIds
    case identifier
    case products
    case presentation
    case featureGating
    case introductoryOfferEligibility
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
    // Presentation is a hint, not the surface itself. A block this SDK can't
    // read costs the surface its style, not its ability to be served.
    presentation = try? container.decodeIfPresent(Presentation.self, forKey: .presentation)
    featureGating = try container.decodeIfPresent(String.self, forKey: .featureGating)
    introductoryOfferEligibility = try container.decodeIfPresent(
      String.self,
      forKey: .introductoryOfferEligibility
    )
  }
}
