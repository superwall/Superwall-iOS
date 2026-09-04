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
  static func devServer(surface: DevServerSurface, url: URL) -> Paywall {
    let products = (surface.products ?? [:])
      .sorted { $0.key < $1.key }
      .map { reference, identifier in
        Product(
          name: reference,
          type: .appStore(.init(id: identifier)),
          id: identifier,
          entitlements: []
        )
      }

    var paywall = Paywall(
      databaseId: surface.paywallId ?? "dev:\(surface.kind)/\(surface.id)",
      identifier: surface.identifier ?? "dev:\(surface.id)",
      name: surface.id,
      cacheKey: "dev:\(surface.id):\(url.absoluteString)",
      buildId: "dev",
      url: url,
      urlConfig: WebViewURLConfig(
        endpoints: [WebViewEndpoint(url: url, timeout: 15, percentage: 100)],
        maxAttempts: 1
      ),
      htmlSubstitutions: "",
      presentation: PaywallPresentationInfo(
        style: presentationStyle(for: surface),
        delay: 0
      ),
      backgroundColorHex: "#FFFFFF",
      backgroundColor: .white,
      darkBackgroundColorHex: nil,
      darkBackgroundColor: nil,
      productItems: products,
      productIds: products.map { $0.id },
      appStoreProductIds: products.map { $0.id },
      responseLoadingInfo: .init(),
      webviewLoadingInfo: .init(),
      productsLoadingInfo: .init(),
      shimmerLoadingInfo: .init(),
      paywalljsVersion: "",
      isScrollEnabled: true,
      introOfferEligibility: .automatic
    )
    paywall.isLocal = true
    return paywall
  }

  /// The height a drawer takes when its `config.ts` doesn't name one, as a
  /// percentage of the screen. Matches what `PaywallPresentationStyle/drawer`
  /// documents.
  private static let defaultDrawerHeight: Double = 70

  /// Maps a surface's `config.ts` presentation onto the SDK's styles.
  /// The framework documents `fullscreen` as its default, so anything
  /// missing or unrecognized lands there.
  private static func presentationStyle(
    for surface: DevServerSurface
  ) -> PaywallPresentationStyle {
    switch surface.presentation?.style {
    case "modal":
      return .modal
    case "push":
      return .push
    case "noAnimation":
      return .fullscreenNoAnimation
    case "drawer":
      // A drawer that names only some of its geometry is still a drawer:
      // PaywallPresentationStyle documents 70% of the screen as the default
      // height, and an unset radius means no rounding.
      let drawer = surface.presentation?.drawer
      return .drawer(
        height: drawer?.height ?? defaultDrawerHeight,
        cornerRadius: drawer?.cornerRadius ?? 0
      )
    case "popup":
      // Unlike the drawer, a popup has no documented default size, so one
      // without both dimensions falls back to fullscreen.
      if let popup = surface.presentation?.popup,
        let height = popup.height,
        let width = popup.width {
        return .popup(height: height, width: width, cornerRadius: popup.cornerRadius ?? 0)
      }
      return .fullscreen
    default:
      return .fullscreen
    }
  }
}
