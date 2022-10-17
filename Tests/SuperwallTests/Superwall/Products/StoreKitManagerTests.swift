//
//  StoreKitManagerTests.swift
//  
//
//  Created by Yusuf Tör on 01/09/2022.
//
// swiftlint:disable all

import XCTest
@testable import Superwall
import StoreKit

class StoreKitManagerTests: XCTestCase {
  func test_getProducts_primaryProduct() async {
    let manager = StoreKitManager()

    let primary = MockSkProduct(productIdentifier: "abc")
    let substituteProducts = PaywallProducts(
      primary: primary
    )

    do {
      let (productsById, products) = try await manager.getProducts(withIds: [], substituting: substituteProducts)
      XCTAssertEqual(productsById[primary.productIdentifier], primary)
      XCTAssertEqual(products.first!.id, primary.productIdentifier)
      XCTAssertEqual(products.first!.type, .primary)
    } catch {
      XCTFail("couldn't get products")
    }
  }

  func test_getProducts_primaryAndTertiaryProduct() async {
    let manager = StoreKitManager()

    let primary = MockSkProduct(productIdentifier: "abc")
    let tertiary = MockSkProduct(productIdentifier: "def")
    let substituteProducts = PaywallProducts(
      primary: primary,
      tertiary: tertiary
    )

    do {
      let (productsById, products) = try await manager.getProducts(withIds: [], substituting: substituteProducts)
      XCTAssertEqual(productsById[primary.productIdentifier], primary)
      XCTAssertEqual(products[0].id, primary.productIdentifier)
      XCTAssertEqual(products[0].type, .primary)

      XCTAssertEqual(productsById[tertiary.productIdentifier], tertiary)
      XCTAssertEqual(products[1].id, tertiary.productIdentifier)
      XCTAssertEqual(products[1].type, .tertiary)
    } catch {
      XCTFail("couldn't get products")
    }
  }

  func test_getProducts_primarySecondaryTertiaryProduct() async {
    let manager = StoreKitManager()

    let primary = MockSkProduct(productIdentifier: "abc")
    let secondary = MockSkProduct(productIdentifier: "def")
    let tertiary = MockSkProduct(productIdentifier: "ghi")
    let substituteProducts = PaywallProducts(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary
    )

    do {
      let (productsById, products) = try await manager.getProducts(withIds: [], substituting: substituteProducts)
      XCTAssertEqual(productsById[primary.productIdentifier], primary)
      XCTAssertEqual(products[0].id, primary.productIdentifier)
      XCTAssertEqual(products[0].type, .primary)

      XCTAssertEqual(productsById[secondary.productIdentifier], secondary)
      XCTAssertEqual(products[1].id, secondary.productIdentifier)
      XCTAssertEqual(products[1].type, .secondary)

      XCTAssertEqual(productsById[tertiary.productIdentifier], tertiary)
      XCTAssertEqual(products[2].id, tertiary.productIdentifier)
      XCTAssertEqual(products[2].type, .tertiary)
    } catch {
      XCTFail("couldn't get products")
    }
  }

  func test_getProducts_substitutePrimaryProduct_oneResponseProduct() async {
    let productsResult: Result<Set<SKProduct>, Error> = .success([])
    let productsManager = ProductsManagerMock(productCompletionResult: productsResult)
    let manager = StoreKitManager(productsManager: productsManager)

    let primary = MockSkProduct(productIdentifier: "abc")
    let substituteProducts = PaywallProducts(
      primary: primary
    )

    do {
      let (productsById, products) = try await manager.getProducts(withIds: ["1"], substituting: substituteProducts)
      XCTAssertEqual(productsById.count, 1)
      XCTAssertEqual(productsById[primary.productIdentifier], primary)
      XCTAssertEqual(products.first!.id, primary.productIdentifier)
      XCTAssertEqual(products.first!.type, .primary)
    } catch {
      XCTFail("couldn't get products")
    }
  }

  func test_getProducts_substitutePrimaryProduct_twoResponseProducts() async {
    let responseProduct2 = MockSkProduct(productIdentifier: "2")
    let productsResult: Result<Set<SKProduct>, Error> = .success([
      responseProduct2
    ])
    let productsManager = ProductsManagerMock(productCompletionResult: productsResult)
    let manager = StoreKitManager(productsManager: productsManager)

    let primary = MockSkProduct(productIdentifier: "abc")
    let substituteProducts = PaywallProducts(
      primary: primary
    )

    do {
      let (productsById, products) = try await manager.getProducts(withIds: ["1", "2"], substituting: substituteProducts)
      XCTAssertEqual(productsById.count, 2)
      XCTAssertEqual(productsById[primary.productIdentifier], primary)
      XCTAssertEqual(products.count, 1)
      XCTAssertEqual(products.first!.id, primary.productIdentifier)
      XCTAssertEqual(products.first!.type, .primary)
      XCTAssertEqual(productsById["2"], responseProduct2)
    } catch {
      XCTFail("couldn't get products")
    }
  }
}
