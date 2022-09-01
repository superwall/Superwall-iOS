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
  func test_processSubstituteProducts_primaryProduct() {
    let manager = StoreKitManager()

    let primary = MockSkProduct(productIdentifier: "abc")
    let substituteProducts = PaywallProducts(
      primary: primary
    )

    let expectation = expectation(description: "Processed substitutes")
    manager.processSubstituteProducts(substituteProducts) { productsById, products in
      XCTAssertEqual(productsById[primary.productIdentifier], primary)
      XCTAssertEqual(products.first!.id, primary.productIdentifier)
      XCTAssertEqual(products.first!.type, .primary)

      expectation.fulfill()
    }

    waitForExpectations(timeout: 1)
  }

  func test_processSubstituteProducts_primaryAndTertiaryProduct() {
    let manager = StoreKitManager()

    let primary = MockSkProduct(productIdentifier: "abc")
    let tertiary = MockSkProduct(productIdentifier: "def")
    let substituteProducts = PaywallProducts(
      primary: primary,
      tertiary: tertiary
    )

    let expectation = expectation(description: "Processed substitutes")
    manager.processSubstituteProducts(substituteProducts) { productsById, products in
      XCTAssertEqual(productsById[primary.productIdentifier], primary)
      XCTAssertEqual(products[0].id, primary.productIdentifier)
      XCTAssertEqual(products[0].type, .primary)

      XCTAssertEqual(productsById[tertiary.productIdentifier], tertiary)
      XCTAssertEqual(products[1].id, tertiary.productIdentifier)
      XCTAssertEqual(products[1].type, .tertiary)

      expectation.fulfill()
    }

    waitForExpectations(timeout: 1)
  }

  func test_processSubstituteProducts_primarySecondaryTertiaryProduct() {
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
    manager.processSubstituteProducts(substituteProducts) { productsById, products in
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
    }

    waitForExpectations(timeout: 1)
  }
}
