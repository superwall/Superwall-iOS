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
    return AutomaticPurchaseController(factory: dependencyContainer)
  }()

  func test_getProducts_primaryProduct() async {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.storeKitManager!

    let primary = MockSkProduct(productIdentifier: "abc")
    let substituteProducts = [
      "primary": StoreProduct(sk1Product: primary)
    ]

    do {
      let (productsById, products) = try await manager.getProducts(withIds: [], substituting: substituteProducts)
      XCTAssertEqual(productsById[primary.productIdentifier]?.sk1Product, primary)
      XCTAssertTrue(products.contains { $0.id == primary.productIdentifier })
      XCTAssertTrue(products.contains { $0.name == "primary" })

      XCTAssertEqual(products.count, 1)
    } catch {
      XCTFail("couldn't get products")
    }
  }

  func test_getProducts_primaryAndTertiaryProduct() async {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.storeKitManager!

    let primary = MockSkProduct(productIdentifier: "abc")
    let tertiary = MockSkProduct(productIdentifier: "def")
    let substituteProducts = [
      "primary": StoreProduct(sk1Product: primary),
      "tertiary": StoreProduct(sk1Product: tertiary)
    ]

    do {
      let (productsById, products) = try await manager.getProducts(withIds: [], substituting: substituteProducts)
      XCTAssertEqual(productsById[primary.productIdentifier]?.sk1Product, primary)
      XCTAssertTrue(products.contains { $0.id == primary.productIdentifier })
      XCTAssertTrue(products.contains { $0.name == "primary" })
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
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.storeKitManager!

    let primary = MockSkProduct(productIdentifier: "abc")
    let secondary = MockSkProduct(productIdentifier: "def")
    let tertiary = MockSkProduct(productIdentifier: "ghi")
    let substituteProducts = [
      "primary": StoreProduct(sk1Product: primary),
      "secondary": StoreProduct(sk1Product: secondary),
      "tertiary": StoreProduct(sk1Product: tertiary)
    ]

    do {
      let (productsById, products) = try await manager.getProducts(withIds: [], substituting: substituteProducts)
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
    let productsFetcher = ProductsFetcherSK1Mock(productCompletionResult: productsResult)
    let manager = StoreKitManager(
      productsFetcher: productsFetcher
    )

    let primary = MockSkProduct(productIdentifier: "abc")
    let substituteProducts = [
      "primary": StoreProduct(sk1Product: primary)
    ]

    do {
      let (productsById, products) = try await manager.getProducts(withIds: ["1"], substituting: substituteProducts)
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
      StoreProduct(sk1Product: responseProduct2)
    ])
    let productsFetcher = ProductsFetcherSK1Mock(productCompletionResult: productsResult)
    let manager = StoreKitManager(
      productsFetcher: productsFetcher
    )

    let primary = MockSkProduct(productIdentifier: "abc")
    let substituteProducts = [
      "primary": StoreProduct(sk1Product: primary)
    ]

    do {
      let (productsById, products) = try await manager.getProducts(withIds: ["1", "2"], substituting: substituteProducts)
      XCTAssertEqual(productsById.count, 2)
      XCTAssertEqual(productsById[primary.productIdentifier]?.sk1Product, primary)
      XCTAssertEqual(products.count, 1)
      XCTAssertTrue(products.contains { $0.id == primary.productIdentifier })
      XCTAssertTrue(products.contains { $0.name == "primary" })
      XCTAssertEqual(productsById["2"]?.sk1Product, responseProduct2)
    } catch {
      XCTFail("couldn't get products")
    }
  }
}
