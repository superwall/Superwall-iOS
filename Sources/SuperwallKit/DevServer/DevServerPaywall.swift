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
  /// if any. The surface owns what renders — its bytes, its products, and
  /// whatever its `config.ts` settings say, which the manifest carries. The
  /// dashboard owns what the manifest cannot express, so `published` fills
  /// every silence: a setting the manifest declares wins, one it leaves out
  /// is inherited, and with neither the safe default stands.
  ///
  /// Two fields are never taken from the manifest, both marked below:
  /// `localNotifications`, which the local paywall declares itself in messages
  /// rather than here, and `onDeviceCache`, which stays `.disabled` so a
  /// live-reloading local page is never served from the web view's cache.
  ///
  /// Anything added to `Paywall` later defaults to the local stub's value, so
  /// if the dashboard configures it and the local paywall has no way of its
  /// own to say otherwise, it belongs in the inherited list below.
  static func devServer(
    surface: DevServerSurface,
    url: URL,
    inheriting published: Paywall? = nil
  ) -> Paywall {
    let products = productItems(from: surface)

    // Identity comes from the paywall being stood in for, not the surface:
    // one surface can serve several dashboard paywalls (an explicit multi-way
    // binding, or the single-paywall fallback), and these reach analytics as
    // paywall_id/paywall_identifier and key the view controller cache. Taking
    // them from the surface would collapse every paywall it serves into one.
    let databaseId: String = published?.databaseId
      ?? surface.paywallId
      ?? "dev:\(surface.kind)/\(surface.id)"
    let identifier: String = published?.identifier
      ?? surface.identifier
      ?? "dev:\(surface.id)"
    let cacheKey = "dev:\(surface.id):\(url.absoluteString)"
    let responseLoadingInfo: LoadingInfo = published?.responseLoadingInfo ?? .init()
    // What config.ts declares comes off the manifest; what it cannot express
    // comes off the published paywall; with neither, the safe default stands.
    let settings = surface.settings
    let featureGating: FeatureGatingBehavior = settings?.featureGating
      ?? published?.featureGating
      ?? .nonGated
    let computedPropertyRequests: [ComputedPropertyRequest] = published?.computedPropertyRequests ?? []
    let surveys: [Survey] = published?.surveys ?? []
    let introOfferEligibility: IntroOfferEligibility = published?.introOfferEligibility ?? .automatic
    let presentation = PaywallPresentationInfo(
      style: settings?.presentationStyle ?? published?.presentation.style ?? .fullscreen,
      delay: published?.presentation.delay ?? 0
    )
    let backgroundColorHex = settings?.backgroundColorHex ?? published?.backgroundColorHex
    let darkBackgroundColorHex = settings?.darkBackgroundColorHex
      ?? published?.darkBackgroundColorHex

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
      backgroundColorHex: backgroundColorHex ?? "#FFFFFF",
      backgroundColor: backgroundColorHex.map { UIColor(hexString: $0) } ?? .white,
      darkBackgroundColorHex: darkBackgroundColorHex,
      darkBackgroundColor: darkBackgroundColorHex.map { UIColor(hexString: $0) },
      productItems: products,
      productIds: products.map { $0.id },
      appStoreProductIds: products.map { $0.id },
      responseLoadingInfo: responseLoadingInfo,
      webviewLoadingInfo: .init(),
      productsLoadingInfo: .init(),
      shimmerLoadingInfo: .init(),
      paywalljsVersion: "",
      featureGating: featureGating,
      // Never taken from either side: a dev server reloads the page on every
      // edit, and DependencyContainer feeds this straight into the web view,
      // so an enabled cache — which the manifest reports, because push stamps
      // it — could serve a stale copy of the local page.
      onDeviceCache: .disabled,
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
      isScrollEnabled: settings?.isScrollEnabled ?? published?.isScrollEnabled ?? true,
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
