//
//  WebProductPricingTests.swift
//
//
//  Created by Jordan Morgan on 26/08/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("Web product pricing")
struct WebProductPricingTests {
  /// Mirrors the `/v1/products` payload for a Stripe product. StoreKit can't resolve one of
  /// these, so the Superwall catalogue is the only place its price exists.
  private func decodeProduct(amountInCents: Int, currency: String = "USD") throws -> SuperwallProduct {
    let json = """
    {
      "object": "product",
      "identifier": "web_pro_monthly",
      "platform": "stripe",
      "price": { "amount": \(amountInCents), "currency": "\(currency)" },
      "subscription": {
        "period": "month",
        "period_count": 1,
        "trial_period_days": null,
        "trial_period_price": null
      },
      "entitlements": [{ "identifier": "pro", "type": "SERVICE_LEVEL" }],
      "storefront": "USA"
    }
    """
    return try JSONDecoder().decode(SuperwallProduct.self, from: Data(json.utf8))
  }

  @Test("a catalogue product carries a price the Customer Center can show")
  func catalogueProductHasPrice() throws {
    let product = try decodeProduct(amountInCents: 999)
    let storeProduct = StoreProduct(
      catalogProduct: APIStoreProduct(superwallProduct: product, entitlements: [])
    )
    let display = ProductDisplayInfo(storeProduct)

    #expect(display.productId == "web_pro_monthly")
    // The payload is in minor units; the card shows a formatted major-unit price.
    #expect(display.price == Decimal(9.99))
    #expect(display.localizedPrice?.contains("9.99") == true)
    #expect(display.localizedPeriod != nil, "the renewal line reads better with a period")
  }

  /// Before this, a web subscription rendered with the raw product identifier as its title and no
  /// price at all, because `products(for:)` only ever consulted StoreKit.
  @Test("the card shows a price rather than a bare identifier", arguments: [199, 999, 7999])
  func cardShowsPrice(amountInCents: Int) throws {
    let product = try decodeProduct(amountInCents: amountInCents)
    let storeProduct = StoreProduct(
      catalogProduct: APIStoreProduct(superwallProduct: product, entitlements: [])
    )
    let display = ProductDisplayInfo(storeProduct)

    let subscription = SubscriptionTransaction(
      transactionId: "web_1",
      productId: "web_pro_monthly",
      purchaseDate: Date().addingTimeInterval(-30 * 86_400),
      willRenew: true,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: Date().addingTimeInterval(12 * 86_400),
      subscriptionGroupId: nil,
      store: .stripe
    )
    let builder = PurchasePresentationBuilder(strings: .english, locale: Locale(identifier: "en_US"))
    let presentations = builder.build(
      customerInfo: CustomerInfo(subscriptions: [subscription], nonSubscriptions: [], entitlements: []),
      products: ["web_pro_monthly": display]
    )
    let card = try #require(presentations.first)

    #expect(card.priceLine != nil)
    #expect(card.statusLine.contains(display.localizedPrice ?? "!"), "the renewal line quotes the price")
    // Still the raw identifier: `/v1/products` returns no display name, so `APIStoreProduct`
    // falls back to the id. The price is the half we can fix from the client; showing
    // "Pro Monthly" instead of "web_pro_monthly" needs a name on that payload.
    #expect(card.title == "web_pro_monthly")
  }

  @Test("a product with no price still renders, just without one")
  func missingPriceDegradesGracefully() throws {
    let json = """
    {
      "object": "product",
      "identifier": "web_pro_monthly",
      "platform": "stripe",
      "price": null,
      "subscription": null,
      "entitlements": [],
      "storefront": "USA"
    }
    """
    let product = try JSONDecoder().decode(SuperwallProduct.self, from: Data(json.utf8))
    let storeProduct = StoreProduct(
      catalogProduct: APIStoreProduct(superwallProduct: product, entitlements: [])
    )
    let display = ProductDisplayInfo(storeProduct)
    #expect(display.price == 0)
  }
}
