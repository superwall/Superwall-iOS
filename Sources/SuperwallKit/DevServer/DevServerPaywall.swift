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
    // The surface's own config.ts wins, then the dashboard's published
    // setting, then the safe default. That order is what lets an unpushed
    // config.ts edit take effect while a bound paywall still behaves like
    // production until you change it.
    let featureGating: FeatureGatingBehavior = gating(from: surface)
      ?? published?.featureGating
      ?? .nonGated
    let computedPropertyRequests: [ComputedPropertyRequest] = published?.computedPropertyRequests ?? []
    let surveys: [Survey] = published?.surveys ?? []
    let introOfferEligibility: IntroOfferEligibility = eligibility(from: surface)
      ?? published?.introOfferEligibility
      ?? .automatic
    let presentation: PaywallPresentationInfo
    if let style = presentationStyle(for: surface) {
      presentation = PaywallPresentationInfo(style: style, delay: 0)
    } else {
      presentation = published?.presentation ?? PaywallPresentationInfo(style: .fullscreen, delay: 0)
    }

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

  /// Maps a surface's `config.ts` feature gating onto the SDK's enum.
  ///
  /// Returns nil for anything unrecognised — including a CLI newer than this
  /// SDK — so the caller falls back rather than guessing how a feature gates.
  private static func gating(from surface: DevServerSurface) -> FeatureGatingBehavior? {
    switch surface.featureGating {
    case "gated":
      return .gated
    case "nonGated":
      return .nonGated
    default:
      return nil
    }
  }

  /// Maps a surface's `config.ts` trial eligibility onto the SDK's enum,
  /// returning nil for anything unrecognised.
  private static func eligibility(from surface: DevServerSurface) -> IntroOfferEligibility? {
    switch surface.introductoryOfferEligibility {
    case "automatic":
      return .automatic
    case "alwaysEligible":
      return .eligible
    case "alwaysIneligible":
      return .ineligible
    default:
      return nil
    }
  }

  /// Geometry a `config.ts` presentation block gets when it doesn't name its
  /// own. These mirror the `superwall` CLI's DRAWER_DEFAULTS and
  /// POPUP_DEFAULTS, which resolve the same values on push, so a partly
  /// specified block presents identically before and after one. The drawer
  /// height also matches what `PaywallPresentationStyle/drawer` documents.
  private static let defaultDrawerHeight: Double = 70
  private static let defaultDrawerCornerRadius: Double = 15
  private static let defaultPopupWidth: Double = 80
  private static let defaultPopupHeight: Double = 60
  private static let defaultPopupCornerRadius: Double = 15

  /// Maps a surface's `config.ts` presentation onto the SDK's styles.
  /// The framework documents `fullscreen` as its default, so anything
  /// missing or unrecognized lands there.
  private static func presentationStyle(
    for surface: DevServerSurface
  ) -> PaywallPresentationStyle? {
    if surface.presentation == nil {
      // The manifest says nothing about presentation, so the dashboard's
      // style stands rather than being replaced by a guess.
      return nil
    }
    switch surface.presentation?.style {
    case "modal":
      return .modal
    case "push":
      return .push
    case "noAnimation":
      return .fullscreenNoAnimation
    case "drawer":
      // A drawer that names only some of its geometry is still a drawer.
      // These match the CLI's own DRAWER_DEFAULTS, so a partly specified
      // drawer looks the same here as it will once it's pushed.
      let drawer = surface.presentation?.drawer
      return .drawer(
        height: drawer?.height ?? defaultDrawerHeight,
        cornerRadius: drawer?.cornerRadius ?? defaultDrawerCornerRadius
      )
    case "popup":
      let popup = surface.presentation?.popup
      return .popup(
        height: popup?.height ?? defaultPopupHeight,
        width: popup?.width ?? defaultPopupWidth,
        cornerRadius: popup?.cornerRadius ?? defaultPopupCornerRadius
      )
    default:
      return .fullscreen
    }
  }
}
