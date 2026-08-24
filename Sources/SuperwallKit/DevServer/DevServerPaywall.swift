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

    return Paywall(
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
      presentation: PaywallPresentationInfo(style: .modal, delay: 0),
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
  }
}
