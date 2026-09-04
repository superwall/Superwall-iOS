//
//  DevServerPaywall.swift
//  SuperwallKit
//
//  Builds a `Paywall` for a surface that a running `superwall dev` server
//  serves, so the debugger can preview local paywall code that has never
//  been pushed to the dashboard.
//

import Foundation
import UIKit

extension Paywall {
  /// Builds the paywall a dev server surface presents.
  ///
  /// - Parameter published: the dashboard paywall this surface stands in for,
  /// if any. The surface owns what renders and how — its bytes, products and
  /// `config.ts` presentation style. Everything the dashboard configures that
  /// a manifest can't express is inherited from `published` instead, so dev
  /// mode changes how a paywall looks and never how it behaves.
  ///
  /// Anything added to `Paywall` later defaults to the local stub's value, so
  /// if it is dashboard-owned behaviour it belongs in the inherited list below.
  static func devServer(
    surface: DevServerSurface,
    url: URL,
    inheriting published: Paywall? = nil
  ) -> Paywall {
    let products = productItems(from: surface)

    let databaseId: String = surface.paywallId ?? "dev:\(surface.kind)/\(surface.id)"
    let identifier: String = surface.identifier ?? "dev:\(surface.id)"
    let cacheKey = "dev:\(surface.id):\(url.absoluteString)"
    let responseLoadingInfo: LoadingInfo = published?.responseLoadingInfo ?? .init()
    // A paywall's config.ts settings reach the SDK in the pushed snapshot,
    // not the dev manifest, so they come from the published paywall this
    // surface stands in for. Without one — a surface that has never been
    // pushed — the safe defaults stand.
    let featureGating: FeatureGatingBehavior = published?.featureGating ?? .nonGated
    let computedPropertyRequests: [ComputedPropertyRequest] = published?.computedPropertyRequests ?? []
    let surveys: [Survey] = published?.surveys ?? []
    let introOfferEligibility: IntroOfferEligibility = published?.introOfferEligibility ?? .automatic
    let presentation = published?.presentation
      ?? PaywallPresentationInfo(style: .fullscreen, delay: 0)

    var paywall = Paywall(
      databaseId: databaseId,
      identifier: identifier,
      name: surface.id,
      cacheKey: cacheKey,
      buildId: "dev",
      url: url,
      urlConfig: WebViewURLConfig(
        endpoints: [WebViewEndpoint(url: url, timeout: 15, percentage: 100)],
        maxAttempts: 1
      ),
      htmlSubstitutions: "",
      presentation: presentation,
      backgroundColorHex: published?.backgroundColorHex ?? "#FFFFFF",
      backgroundColor: published?.backgroundColor ?? .white,
      darkBackgroundColorHex: published?.darkBackgroundColorHex,
      darkBackgroundColor: published?.darkBackgroundColor,
      productItems: products,
      productIds: products.map { $0.id },
      appStoreProductIds: products.map { $0.id },
      responseLoadingInfo: responseLoadingInfo,
      webviewLoadingInfo: .init(),
      productsLoadingInfo: .init(),
      shimmerLoadingInfo: .init(),
      paywalljsVersion: "",
      // Feature gating decides whether a non-paying user gets the feature, so
      // it can never come from local paywall code.
      featureGating: featureGating,
      // Deliberately not inherited: a local paywall declares its own
      // notifications in config.ts, and they reach the SDK as
      // `schedule_notification` messages rather than through this field.
      // Inheriting the dashboard's would let a stale copy win the
      // paywallId+type dedupe in NotificationScheduler.
      localNotifications: [],
      // The variables the page reads: without these, a local render silently
      // lacks computed properties that production resolves.
      computedPropertyRequests: computedPropertyRequests,
      surveys: surveys,
      isScrollEnabled: published?.isScrollEnabled ?? true,
      // Drives displayed trial state and pricing, which is exactly what a
      // local preview is checked against.
      introOfferEligibility: introOfferEligibility
    )
    paywall.isLocal = true
    paywall.experiment = published?.experiment
    return paywall
  }

  /// The products a surface's `config.ts` declares, in a stable order.
  private static func productItems(from surface: DevServerSurface) -> [Product] {
    return (surface.products ?? [:])
      .sorted { $0.key < $1.key }
      .map { reference, identifier in
        Product(
          name: reference,
          type: .appStore(.init(id: identifier)),
          id: identifier,
          entitlements: []
        )
      }
  }
}
