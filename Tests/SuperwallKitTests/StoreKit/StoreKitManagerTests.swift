//
//  StoreKitManagerTests.swift
//  
//
//  Created by Yusuf Tör on 01/09/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit
import StoreKit

class StoreKitManagerTests: XCTestCase {
  let dependencyContainer = DependencyContainer()
  lazy var purchaseController: AutomaticPurchaseController = {
    return AutomaticPurchaseController(factory: dependencyContainer, entitlementsInfo: dependencyContainer.entitlementsInfo)
  }()

  func test_getProducts_primaryProduct() async {
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
    do {
      let (productsById, products) = try await manager.getProducts(
        forPaywall: paywall,
        placement: nil,
        substituting: substituteProducts
      )
      XCTAssertEqual(productsById[primary.productIdentifier]?.sk1Product, primary)
      XCTAssertTrue(products.contains { $0.id == primary.productIdentifier })
      XCTAssertTrue(products.contains { $0.name == "primary" })
      XCTAssertTrue(products.contains { $0.entitlements == entitlements })

      XCTAssertEqual(products.count, 1)
    } catch {
      XCTFail("couldn't get products")
    }
  }

  func test_getProducts_primaryAndTertiaryProduct() async {
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

    do {
      let (productsById, products) = try await manager.getProducts(
        forPaywall: paywall,
        placement: nil,
        substituting: substituteProducts
      )
      XCTAssertEqual(productsById[primary.productIdentifier]?.sk1Product, primary)
      XCTAssertTrue(products.contains { $0.id == primary.productIdentifier })
      XCTAssertTrue(products.contains { $0.name == "primary" })
      XCTAssertTrue(products.contains { $0.entitlements == primaryEntitlements })
      XCTAssertTrue(products.contains { $0.objcAdapter.store == .appStore })
      XCTAssertTrue(products.contains { $0.id == tertiary.productIdentifier })
      XCTAssertTrue(products.contains { $0.name == "tertiary" })
      XCTAssertEqual(products.count, 2)

      XCTAssertEqual(productsById[tertiary.productIdentifier]?.sk1Product, tertiary)
    } catch {
      XCTFail("couldn't get products")
    }
  }

  func test_getProducts_primarySecondaryTertiaryProduct() async {
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
    do {
      let (productsById, products) = try await manager.getProducts(
        forPaywall: paywall,
        placement: nil,
        substituting: substituteProducts
      )
      XCTAssertEqual(productsById[primary.productIdentifier]?.sk1Product, primary)
      XCTAssertTrue(products.contains { $0.id == primary.productIdentifier })
      XCTAssertTrue(products.contains { $0.name == "primary" })

      XCTAssertEqual(productsById[secondary.productIdentifier]?.sk1Product, secondary)
      XCTAssertTrue(products.contains { $0.id == secondary.productIdentifier })
      XCTAssertTrue(products.contains { $0.name == "secondary" })

      XCTAssertEqual(productsById[tertiary.productIdentifier]?.sk1Product, tertiary)
      XCTAssertTrue(products.contains { $0.id == tertiary.productIdentifier })
      XCTAssertTrue(products.contains { $0.name == "tertiary" })
      XCTAssertEqual(products.count, 3)
    } catch {
      XCTFail("couldn't get products")
    }
  }

  func test_getProducts_substitutePrimaryProduct_oneResponseProduct() async {
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
    do {
      let (productsById, products) = try await manager.getProducts(
        forPaywall: paywall,
        placement: nil,
        substituting: substituteProducts
      )
      XCTAssertEqual(productsById.count, 1)
      XCTAssertEqual(productsById[primary.productIdentifier]?.sk1Product, primary)
      XCTAssertTrue(products.contains { $0.id == primary.productIdentifier })
      XCTAssertTrue(products.contains { $0.name == "primary" })
      XCTAssertEqual(products.count, 1)
    } catch {
      XCTFail("couldn't get products")
    }
  }

  func test_getProducts_substitutePrimaryProduct_twoResponseProducts() async {
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

    do {
      let (productsById, products) = try await manager.getProducts(
        forPaywall: paywall,
        placement: nil,
        substituting: substituteProducts
      )
      XCTAssertEqual(productsById.count, 2)
      XCTAssertEqual(productsById[primary.productIdentifier]?.sk1Product, primary)
      XCTAssertEqual(products.count, 2)
      XCTAssertTrue(products.contains { $0.id == primary.productIdentifier })
      XCTAssertTrue(products.contains { $0.name == "primary" })
      XCTAssertEqual(productsById["2"]?.sk1Product, responseProduct2)
    } catch {
      XCTFail("couldn't get products")
    }
  }
}
