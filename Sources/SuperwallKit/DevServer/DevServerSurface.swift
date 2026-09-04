//
//  DevServerSurface.swift
//  SuperwallKit
//
//  One entry in the surface list a running `superwall dev` server exposes:
//  a locally served paywall or funnel, and the dashboard paywall it is
//  bound to via `superwall.lock`, if any.
//
//  The manifest carries identity and products only. Everything else a
//  paywall's config.ts declares — presentation, feature gating, intro offer
//  eligibility — travels to the dashboard in the pushed snapshot instead, so
//  the SDK reads those from the published paywall the surface stands in for.
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
}
