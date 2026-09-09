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
  private func decodeProduct(
    amountInCents: Int,
    currency: String = "USD",
    name: String? = nil,
    identifier: String = "web_pro_monthly",
    platform: String = "stripe"
  ) throws -> SuperwallProduct {
    let nameField = name.map { "\"name\": \"\($0)\"," } ?? ""
    let json = """
    {
      "object": "product",
      "identifier": "\(identifier)",
      \(nameField)
      "platform": "\(platform)",
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
    // No name in the payload today, so the identifier stands in. Deliberately not prettified:
    // a composed identifier like `live:price_123:no-trial` would tidy into a plausible-looking
    // product name that is pure fiction, and the real Stripe name is per-product anyway
    // ("Pro"), not per-price ("Pro Monthly").
    #expect(card.title == "web_pro_monthly")
  }

  /// The field the backend hasn't shipped yet. Pins that `name` decodes off the payload and that
  /// `ProductDisplayInfo` honours it; the call site that passes it through is covered separately,
  /// by `catalogueNameReachesTheCard` below.
  @Test("uses the catalogue's display name as soon as the payload carries one")
  func usesDisplayNameWhenPresent() throws {
    let product = try decodeProduct(amountInCents: 999, name: "Pro")
    let storeProduct = StoreProduct(
      catalogProduct: APIStoreProduct(superwallProduct: product, entitlements: [])
    )

    #expect(ProductDisplayInfo(storeProduct, name: product.name).title == "Pro")
    #expect(ProductDisplayInfo(storeProduct).title == "web_pro_monthly", "no name given, no name used")
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

  // MARK: - The rule that decides what the catalogue is allowed to fill

  private func displayInfo(for identifier: String) throws -> ProductDisplayInfo {
    let product = try decodeProduct(amountInCents: 100, identifier: identifier)
    return ProductDisplayInfo(StoreProduct(catalogProduct: APIStoreProduct(superwallProduct: product, entitlements: [])))
  }

  @Test("fills only the products StoreKit couldn't resolve")
  func fillsOnlyTheGaps() throws {
    let fromStoreKit = try displayInfo(for: "ios_pro_monthly")
    let catalogue = [
      try decodeProduct(amountInCents: 999, identifier: "web_pro_monthly"),
      try decodeProduct(amountInCents: 500, identifier: "web_unrelated")
    ]

    let filled = LiveProductsProvider.fillingGaps(
      in: ["ios_pro_monthly": fromStoreKit],
      requested: ["ios_pro_monthly", "web_pro_monthly"],
      from: catalogue
    )

    #expect(filled.keys.sorted() == ["ios_pro_monthly", "web_pro_monthly"])
    #expect(filled["web_pro_monthly"]?.localizedPrice?.contains("9.99") == true)
    #expect(filled["web_unrelated"] == nil, "a catalogue entry nobody asked about is not a gap")
  }

  /// The restriction that matters for money. `products(for:)` swallows a failed StoreKit lookup
  /// with `try?`, so an App Store product can land in the gap — and the catalogue holds the
  /// dashboard's storefront price, not what this customer is actually charged in theirs.
  @Test("never fills an App Store product from the catalogue")
  func neverFillsAppStoreProducts() throws {
    let catalogue = [try decodeProduct(amountInCents: 999, identifier: "ios_pro_monthly", platform: "ios")]

    let filled = LiveProductsProvider.fillingGaps(
      in: [:],
      requested: ["ios_pro_monthly"],
      from: catalogue
    )

    #expect(filled.isEmpty, "better no price than a price from the wrong storefront")
  }

  @Test("what StoreKit resolved is never overwritten")
  func storeKitWins() throws {
    let fromStoreKit = try displayInfo(for: "web_pro_monthly")
    let catalogue = [try decodeProduct(amountInCents: 9_999, identifier: "web_pro_monthly")]

    let filled = LiveProductsProvider.fillingGaps(
      in: ["web_pro_monthly": fromStoreKit],
      requested: ["web_pro_monthly"],
      from: catalogue
    )

    #expect(filled["web_pro_monthly"]?.localizedPrice == fromStoreKit.localizedPrice)
  }

  /// The other half of `usesDisplayNameWhenPresent`: that the call site actually passes the name
  /// through. Deleting `name:` from `fillingGaps` leaves that test green and fails this one.
  @Test("the catalogue's name reaches the card")
  func catalogueNameReachesTheCard() throws {
    let catalogue = [try decodeProduct(amountInCents: 999, name: "Pro")]

    let filled = LiveProductsProvider.fillingGaps(
      in: [:],
      requested: ["web_pro_monthly"],
      from: catalogue
    )

    #expect(filled["web_pro_monthly"]?.title == "Pro")
  }

  @Test("nothing missing means nothing to do")
  func noGapsNoWork() throws {
    let fromStoreKit = try displayInfo(for: "web_pro_monthly")
    let catalogue = [try decodeProduct(amountInCents: 9_999, identifier: "other")]

    let filled = LiveProductsProvider.fillingGaps(
      in: ["web_pro_monthly": fromStoreKit],
      requested: ["web_pro_monthly"],
      from: catalogue
    )

    #expect(filled.count == 1)
  }
}
