//
//  StoreKitManagerTests.swift
//  
//
//  Created by Yusuf Tör on 01/09/2022.
//
// swiftlint:disable all

import XCTest
@testable import Paywall
import StoreKit

class StoreKitManagerTests: XCTestCase {
  func test_getProducts_primaryProduct() {
    let manager = StoreKitManager()

    let primary = MockSkProduct(productIdentifier: "abc")
    let substituteProducts = PaywallProducts(
      primary: primary
    )

    let expectation = expectation(description: "Processed substitutes")
    manager.getProducts(withIds: [], substituting: substituteProducts) { result in
      switch result {
      case let .success((productsById, products)):
        XCTAssertEqual(productsById[primary.productIdentifier], primary)
        XCTAssertEqual(products.first!.id, primary.productIdentifier)
        XCTAssertEqual(products.first!.type, .primary)
        expectation.fulfill()
      case .failure:
        XCTFail("couldn't get products")
      }
    }

    waitForExpectations(timeout: 1)
  }

  func test_getProducts_primaryAndTertiaryProduct() {
    let manager = StoreKitManager()

    let primary = MockSkProduct(productIdentifier: "abc")
    let tertiary = MockSkProduct(productIdentifier: "def")
    let substituteProducts = PaywallProducts(
      primary: primary,
      tertiary: tertiary
    )

    let expectation = expectation(description: "Processed substitutes")
    manager.getProducts(withIds: [], substituting: substituteProducts) { result in
      switch result {
      case let .success((productsById, products)):
        XCTAssertEqual(productsById[primary.productIdentifier], primary)
        XCTAssertEqual(products[0].id, primary.productIdentifier)
        XCTAssertEqual(products[0].type, .primary)

        XCTAssertEqual(productsById[tertiary.productIdentifier], tertiary)
        XCTAssertEqual(products[1].id, tertiary.productIdentifier)
        XCTAssertEqual(products[1].type, .tertiary)

        expectation.fulfill()
      case .failure:
        XCTFail("couldn't get products")
      }
    }

    waitForExpectations(timeout: 1)
  }

  func test_getProducts_primarySecondaryTertiaryProduct() {
    let manager = StoreKitManager()

    let primary = MockSkProduct(productIdentifier: "abc")
    let secondary = MockSkProduct(productIdentifier: "def")
    let tertiary = MockSkProduct(productIdentifier: "ghi")
    let substituteProducts = PaywallProducts(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary
    )

    let expectation = expectation(description: "Processed substitutes")
    manager.getProducts(withIds: [], substituting: substituteProducts) { result in
      switch result {
      case let .success((productsById, products)):
        XCTAssertEqual(productsById[primary.productIdentifier], primary)
        XCTAssertEqual(products[0].id, primary.productIdentifier)
        XCTAssertEqual(products[0].type, .primary)

        XCTAssertEqual(productsById[secondary.productIdentifier], secondary)
        XCTAssertEqual(products[1].id, secondary.productIdentifier)
        XCTAssertEqual(products[1].type, .secondary)

        XCTAssertEqual(productsById[tertiary.productIdentifier], tertiary)
        XCTAssertEqual(products[2].id, tertiary.productIdentifier)
        XCTAssertEqual(products[2].type, .tertiary)

        expectation.fulfill()
      case .failure:
        XCTFail("couldn't get products")
      }
    }

    waitForExpectations(timeout: 1)
  }

  func test_getProducts_substitutePrimaryProduct_oneResponseProduct() {
    let productsResult: Result<Set<SKProduct>, Error> = .success([])
    let productsManager = ProductsManagerMock(productCompletionResult: productsResult)
    let manager = StoreKitManager(productsManager: productsManager)

    let primary = MockSkProduct(productIdentifier: "abc")
    let substituteProducts = PaywallProducts(
      primary: primary
    )

    let expectation = expectation(description: "Processed substitutes")
    manager.getProducts(withIds: ["1"], substituting: substituteProducts) { result in
      switch result {
      case let .success((productsById, substituteProducts)):
        XCTAssertEqual(productsById.count, 1)
        XCTAssertEqual(productsById[primary.productIdentifier], primary)
        XCTAssertEqual(substituteProducts.first!.id, primary.productIdentifier)
        XCTAssertEqual(substituteProducts.first!.type, .primary)
        expectation.fulfill()
      case .failure:
        XCTFail("couldn't get products")
      }
    }

    waitForExpectations(timeout: 1)
  }

  func test_getProducts_substitutePrimaryProduct_twoResponseProducts() {
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

    let expectation = expectation(description: "Processed substitutes")
    manager.getProducts(withIds: ["1", "2"], substituting: substituteProducts) { result in
      switch result {
      case let .success((productsById, substituteProducts)):
        XCTAssertEqual(productsById.count, 2)
        XCTAssertEqual(productsById[primary.productIdentifier], primary)
        XCTAssertEqual(substituteProducts.count, 1)
        XCTAssertEqual(substituteProducts.first!.id, primary.productIdentifier)
        XCTAssertEqual(substituteProducts.first!.type, .primary)
        XCTAssertEqual(productsById["2"], responseProduct2)
        expectation.fulfill()
      case .failure:
        XCTFail("couldn't get products")
      }
    }

    waitForExpectations(timeout: 1)
  }
}
