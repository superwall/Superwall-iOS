//
//  CustomerCenterDependenciesTests.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Testing
import Foundation
@testable import SuperwallKit
import StoreKit

@Suite("CustomerCenterDependencies")
struct CustomerCenterDependenciesTests {
  @Test("web management URL: override wins; superwall.app host → /manage; other host → restore URL; none → nil")
  func webURL() {
    let override = URL(string: "https://me.com/manage")!
    let restore = URL(string: "https://caffeinepal.superwall.app/restore?x=1")!
    #expect(WebManagementURLResolver.resolve(override: override, restoreAccessURL: restore) == override)
    #expect(WebManagementURLResolver.resolve(override: nil, restoreAccessURL: restore) == URL(string: "https://caffeinepal.superwall.app/manage"))
    let other = URL(string: "https://example.com/restore")!
    #expect(WebManagementURLResolver.resolve(override: nil, restoreAccessURL: other) == other)
    #expect(WebManagementURLResolver.resolve(override: nil, restoreAccessURL: nil) == nil)
    // Lookalike host: a suffix match without a dot boundary would wrongly treat this as
    // a superwall.app subdomain and rewrite it. It must pass through unchanged.
    let lookalike = URL(string: "https://notsuperwall.app/restore?x=1")!
    #expect(WebManagementURLResolver.resolve(override: nil, restoreAccessURL: lookalike) == lookalike)
  }

  @Test("ProductDisplayInfo init: title present, group id passes through, no period, not auto-renewable for SK1-only product")
  func productDisplayInfoFromSK1WithTitle() {
    let sk1 = MockSkProduct(
      productIdentifier: "monthly",
      subscriptionGroupIdentifier: "group_1",
      localizedTitle: "Monthly Plan"
    )
    let storeProduct = StoreProduct(sk1Product: sk1, entitlements: [])
    let info = ProductDisplayInfo(storeProduct)

    #expect(info.title == "Monthly Plan")
    #expect(info.subscriptionGroupId == "group_1")
    #expect(info.localizedPeriod == nil)
    #expect(info.isAutoRenewable == nil)
  }

  @Test("ProductDisplayInfo init: title falls back to a tidied identifier when the sk1 title is empty")
  func productDisplayInfoFromSK1WithoutTitle() {
    let sk1 = MockSkProduct(productIdentifier: "monthly")
    let storeProduct = StoreProduct(sk1Product: sk1, entitlements: [])
    let info = ProductDisplayInfo(storeProduct)

    // Previously the raw identifier. A card headed "monthly" reads like a bug to a customer, and
    // web products have no name at all to fall back on — see `ProductTitleFormatter`.
    #expect(info.title == "Monthly")
  }
}
