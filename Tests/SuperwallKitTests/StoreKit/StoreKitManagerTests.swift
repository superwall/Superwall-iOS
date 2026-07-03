//
//  StoreKitManagerTests.swift
//
//
//  Created by Yusuf Tör on 01/09/2022.
//
// swiftlint:disable all

import Testing
import Foundation
@testable import SuperwallKit
import StoreKit

@Suite("StoreKitManager Tests")
@MainActor
struct StoreKitManagerTests {
  let dependencyContainer = DependencyContainer()

  @Test("getProducts returns the substituted primary product")
  func getProducts_primaryProduct() async throws {
    let primary = MockSkProduct(productIdentifier: "abc")
    let entitlements: Set<Entitlement> = [.stub()]

    // Mock the products fetcher to return empty set since we're substituting all products
    let productsResult: Result<Set<StoreProduct>, Error> = .success([])
    let productsFetcher = ProductsFetcherSK1Mock(
      productCompletionResult: productsResult,
      entitlementsInfo: dependencyContainer.entitlementsInfo
    )
    let productsManager = ProductsManager(
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      storeKitVersion: .storeKit1,
      productsFetcher: productsFetcher
    )
    let manager = StoreKitManager(
      productsManager: productsManager
    )

    let substituteProducts = [
      "primary": ProductOverride.byProduct(StoreProduct(sk1Product: primary, entitlements: entitlements))
    ]
    let paywall = Paywall.stub()
      .setting(\.products, to: [.init(name: "primary", type: .appStore(.init(id: "xyz")), id: "xyz", entitlements: [])])

    let (productsById, products) = try await manager.getProducts(
      forPaywall: paywall,
      placement: nil,
      substituting: substituteProducts
    )
    #expect(productsById[primary.productIdentifier]?.sk1Product == primary)
    #expect(products.contains { $0.id == primary.productIdentifier })
    #expect(products.contains { $0.name == "primary" })
    #expect(products.contains { $0.entitlements == entitlements })
    #expect(products.count == 1)
  }

  @Test("getProducts returns the substituted primary and tertiary products")
  func getProducts_primaryAndTertiaryProduct() async throws {
    let primary = MockSkProduct(productIdentifier: "abc")
    let primaryEntitlements: Set<Entitlement> = [.stub()]
    let tertiary = MockSkProduct(productIdentifier: "def")

    // Mock the products fetcher to return empty set since we're substituting all products
    let productsResult: Result<Set<StoreProduct>, Error> = .success([])
    let productsFetcher = ProductsFetcherSK1Mock(
      productCompletionResult: productsResult,
      entitlementsInfo: dependencyContainer.entitlementsInfo
    )
    let productsManager = ProductsManager(
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      storeKitVersion: .storeKit1,
      productsFetcher: productsFetcher
    )
    let manager = StoreKitManager(
      productsManager: productsManager
    )

    let substituteProducts = [
      "primary": ProductOverride.byProduct(StoreProduct(sk1Product: primary, entitlements: primaryEntitlements)),
      "tertiary": ProductOverride.byProduct(StoreProduct(sk1Product: tertiary, entitlements: []))
    ]

    let paywall = Paywall.stub()
      .setting(\.products, to: [
        .init(name: "primary", type: .appStore(.init(id: "xyz")), id: "xyz", entitlements: []),
        .init(name: "tertiary", type: .appStore(.init(id: "ghi")), id: "ghi", entitlements: [.stub()]),
      ])

    let (productsById, products) = try await manager.getProducts(
      forPaywall: paywall,
      placement: nil,
      substituting: substituteProducts
    )
    #expect(productsById[primary.productIdentifier]?.sk1Product == primary)
    #expect(products.contains { $0.id == primary.productIdentifier })
    #expect(products.contains { $0.name == "primary" })
    #expect(products.contains { $0.entitlements == primaryEntitlements })
    #expect(products.contains { $0.objcAdapter.store == .appStore })
    #expect(products.contains { $0.id == tertiary.productIdentifier })
    #expect(products.contains { $0.name == "tertiary" })
    #expect(products.count == 2)
    #expect(productsById[tertiary.productIdentifier]?.sk1Product == tertiary)
  }

  @Test("getProducts returns the substituted primary, secondary and tertiary products")
  func getProducts_primarySecondaryTertiaryProduct() async throws {
    let primary = MockSkProduct(productIdentifier: "abc")
    let secondary = MockSkProduct(productIdentifier: "def")
    let tertiary = MockSkProduct(productIdentifier: "ghi")

    // Mock the products fetcher to return empty set since we're substituting all products
    let productsResult: Result<Set<StoreProduct>, Error> = .success([])
    let productsFetcher = ProductsFetcherSK1Mock(
      productCompletionResult: productsResult,
      entitlementsInfo: dependencyContainer.entitlementsInfo
    )
    let productsManager = ProductsManager(
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      storeKitVersion: .storeKit1,
      productsFetcher: productsFetcher
    )
    let manager = StoreKitManager(
      productsManager: productsManager
    )

    let substituteProducts = [
      "primary": StoreProduct(sk1Product: primary, entitlements: []),
      "secondary": StoreProduct(sk1Product: secondary, entitlements: []),
      "tertiary": StoreProduct(sk1Product: tertiary, entitlements: [])
    ].mapValues(ProductOverride.byProduct)
    let paywall = Paywall.stub()
      .setting(\.products, to: [
        .init(name: "primary", type: .appStore(.init(id: "xyz")), id: "xyz", entitlements: []),
        .init(name: "secondary", type: .appStore(.init(id: "123")), id: "123", entitlements: []),
        .init(name: "tertiary", type: .appStore(.init(id: "uiu")), id: "uiu", entitlements: [.stub()]),
      ])

    let (productsById, products) = try await manager.getProducts(
      forPaywall: paywall,
      placement: nil,
      substituting: substituteProducts
    )
    #expect(productsById[primary.productIdentifier]?.sk1Product == primary)
    #expect(products.contains { $0.id == primary.productIdentifier })
    #expect(products.contains { $0.name == "primary" })

    #expect(productsById[secondary.productIdentifier]?.sk1Product == secondary)
    #expect(products.contains { $0.id == secondary.productIdentifier })
    #expect(products.contains { $0.name == "secondary" })

    #expect(productsById[tertiary.productIdentifier]?.sk1Product == tertiary)
    #expect(products.contains { $0.id == tertiary.productIdentifier })
    #expect(products.contains { $0.name == "tertiary" })
    #expect(products.count == 3)
  }

  @Test("getProducts substitutes the primary product when there is one response product")
  func getProducts_substitutePrimaryProduct_oneResponseProduct() async throws {
    let productsResult: Result<Set<StoreProduct>, Error> = .success([])

    let productsFetcher = ProductsFetcherSK1Mock(
      productCompletionResult: productsResult,
      entitlementsInfo: dependencyContainer.entitlementsInfo
    )
    let productsManager = ProductsManager(
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      storeKitVersion: .storeKit1,
      productsFetcher: productsFetcher
    )
    let manager = StoreKitManager(
      productsManager: productsManager
    )

    let primary = MockSkProduct(productIdentifier: "abc")
    let substituteProducts = [
      "primary": StoreProduct(sk1Product: primary, entitlements: [])
    ].mapValues(ProductOverride.byProduct)
    let paywall = Paywall.stub()
      .setting(\.products, to: [
        .init(name: "primary", type: .appStore(.init(id: "1")), id: "1", entitlements: [])
      ])

    let (productsById, products) = try await manager.getProducts(
      forPaywall: paywall,
      placement: nil,
      substituting: substituteProducts
    )
    #expect(productsById.count == 1)
    #expect(productsById[primary.productIdentifier]?.sk1Product == primary)
    #expect(products.contains { $0.id == primary.productIdentifier })
    #expect(products.contains { $0.name == "primary" })
    #expect(products.count == 1)
  }

  @Test("getProducts substitutes the primary product when there are two response products")
  func getProducts_substitutePrimaryProduct_twoResponseProducts() async throws {
    let responseProduct2 = MockSkProduct(productIdentifier: "2")
    let productsResult: Result<Set<StoreProduct>, Error> = .success([
      StoreProduct(sk1Product: responseProduct2, entitlements: [])
    ])
    let productsFetcher = ProductsFetcherSK1Mock(productCompletionResult: productsResult, entitlementsInfo: dependencyContainer.entitlementsInfo)
    let productsManager = ProductsManager(
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      storeKitVersion: .storeKit1,
      productsFetcher: productsFetcher
    )
    let manager = StoreKitManager(
      productsManager: productsManager
    )

    let primary = MockSkProduct(productIdentifier: "abc")
    let substituteProducts = [
      "primary": StoreProduct(sk1Product: primary, entitlements: [])
    ].mapValues(ProductOverride.byProduct)

    let paywall = Paywall.stub()
      .setting(\.products, to: [
        .init(name: "primary", type: .appStore(.init(id: "1")), id: "1", entitlements: []),
        .init(name: "secondary", type: .appStore(.init(id: "2")), id: "2", entitlements: [])
      ])

    let (productsById, products) = try await manager.getProducts(
      forPaywall: paywall,
      placement: nil,
      substituting: substituteProducts
    )
    #expect(productsById.count == 2)
    #expect(productsById[primary.productIdentifier]?.sk1Product == primary)
    #expect(products.count == 2)
    #expect(products.contains { $0.id == primary.productIdentifier })
    #expect(products.contains { $0.name == "primary" })
    #expect(productsById["2"]?.sk1Product == responseProduct2)
  }

  @Test("Composite products from earlier paywalls survive when later paywalls load")
  func getProducts_compositeMapAccumulatesAcrossPaywalls() async throws {
    // A single Apple product (`annual`) merchandised under two different
    // billing plans, each on its own paywall, mirrors preloading multiple
    // billing-plan paywalls into the shared composite-ID cache.
    let annual = MockSkProduct(productIdentifier: "annual")
    let productsResult: Result<Set<StoreProduct>, Error> = .success([
      StoreProduct(sk1Product: annual, entitlements: [])
    ])
    let productsFetcher = ProductsFetcherSK1Mock(
      productCompletionResult: productsResult,
      entitlementsInfo: dependencyContainer.entitlementsInfo
    )
    let productsManager = ProductsManager(
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      storeKitVersion: .storeKit1,
      productsFetcher: productsFetcher
    )
    let manager = StoreKitManager(
      productsManager: productsManager
    )

    let monthlyCommitmentPaywall = Paywall.stub()
      .setting(\.products, to: [
        .init(
          name: "annual",
          type: .appStore(.init(id: "annual", billingPlanType: .monthly)),
          id: "annual:MONTHLY",
          entitlements: []
        )
      ])
    let upFrontPaywall = Paywall.stub()
      .setting(\.products, to: [
        .init(
          name: "annual",
          type: .appStore(.init(id: "annual", billingPlanType: .upFront)),
          id: "annual:UP_FRONT",
          entitlements: []
        )
      ])

    // Load both paywalls in turn, as preloading would.
    _ = try await manager.getProducts(forPaywall: monthlyCommitmentPaywall, placement: nil)
    _ = try await manager.getProducts(forPaywall: upFrontPaywall, placement: nil)

    // Loading the second paywall must not wipe the first paywall's
    // billing-plan product: both composite entries must stay resolvable, since
    // a preloaded paywall is never re-resolved when it's later presented.
    let composite = await manager.productsByCompositeId
    #expect(composite["annual:MONTHLY"] != nil)
    #expect(composite["annual:UP_FRONT"] != nil)
  }
}
