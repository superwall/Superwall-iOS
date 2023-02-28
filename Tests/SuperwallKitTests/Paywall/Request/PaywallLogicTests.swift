//
//  PaywallLogicTests.swift
//  
//
//  Created by Yusuf Tör on 17/03/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit
import StoreKit

@available(iOS 14.0, *)
class PaywallLogicTests: XCTestCase {
  // MARK: - Request Hash
  func testRequestHash_withIdentifierNoEvent() {
    // Given
    let id = "myid"
    let locale = "en_US"

    // When
    let hash = PaywallLogic.requestHash(
      identifier: id,
      locale: locale,
      paywallProducts: nil
    )

    // Then
    XCTAssertEqual(hash, "\(id)_\(locale)_")
  }

  func testRequestHash_withIdentifierWithEvent() {
    // Given
    let id = "myid"
    let locale = "en_US"
    let event: EventData = .stub()

    // When
    let hash = PaywallLogic.requestHash(
      identifier: id,
      event: event,
      locale: locale,
      paywallProducts: nil
    )

    // Then
    XCTAssertEqual(hash, "\(id)_\(locale)_")
  }

  func testRequestHash_withIdentifierWithEventAndProducts() {
    // Given
    let id = "myid"
    let locale = "en_US"
    let event: EventData = .stub()
    let product1 = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "abc"))
    let product2 = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "def"))
    let products = PaywallProducts(primary: product1, secondary: product2)

    // When
    let hash = PaywallLogic.requestHash(
      identifier: id,
      event: event,
      locale: locale,
      paywallProducts: products
    )

    // Then
    XCTAssertEqual(hash, "\(id)_\(locale)_abcdef")
  }

  func testRequestHash_noIdentifierWithEvent() {
    // Given
    let locale = "en_US"
    let eventName = "MyEvent"
    let event: EventData = .stub()
      .setting(\.name, to: eventName)

    // When
    let hash = PaywallLogic.requestHash(
      event: event,
      locale: locale,
      paywallProducts: nil
    )

    // Then
    XCTAssertEqual(hash, "\(eventName)_\(locale)_")
  }

  func testRequestHash_noIdentifierNoEvent() {
    // Given
    let locale = "en_US"

    // When
    let hash = PaywallLogic.requestHash(
      locale: locale,
      paywallProducts: nil
    )

    // Then
    XCTAssertEqual(hash, "$called_manually_\(locale)_")
  }

  func testRequestHash_noIdentifierWithEventAndProducts() {
    // Given
    let locale = "en_US"
    let eventName = "MyEvent"
    let event: EventData = .stub()
      .setting(\.name, to: eventName)
    let product1 = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "abc"))
    let products = PaywallProducts(primary: product1)

    // When
    let hash = PaywallLogic.requestHash(
      event: event,
      locale: locale,
      paywallProducts: products
    )

    // Then
    XCTAssertEqual(hash, "\(eventName)_\(locale)_abc")
  }

  // MARK: - getVariablesAndFreeTrial
  func testGetVariablesAndFreeTrial_noProducts() async {
    let response = await PaywallLogic.getVariablesAndFreeTrial(
      fromProducts: [],
      productsById: [:],
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: { product in return false }
    )

    let expectation = ProductProcessingOutcome(
      productVariables: [],
      swProductVariablesTemplate: [],
      orderedSwProducts: [],
      isFreeTrialAvailable: false
    )

    XCTAssertEqual(response.isFreeTrialAvailable, expectation.isFreeTrialAvailable)
    XCTAssertTrue(response.productVariables.isEmpty)
    XCTAssertTrue(response.swProductVariablesTemplate.isEmpty)
    XCTAssertTrue(response.orderedSwProducts.isEmpty)
  }

  func testGetVariablesAndFreeTrial_productNotFound() async {
    let productId = "id1"
    let products = [Product(
      type: .primary,
      id: productId
    )]

    let skProductId = "id2"
    let skProduct = SKProduct(
      identifier: skProductId,
      price: "1.99"
    )
    let productsById = [skProductId: StoreProduct(sk1Product: skProduct)]
    
    let response = await PaywallLogic.getVariablesAndFreeTrial(
      fromProducts: products,
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: { product in return false }
    )

    let expectation = ProductProcessingOutcome(
      productVariables: [],
      swProductVariablesTemplate: [],
      orderedSwProducts: [],
      isFreeTrialAvailable: false
    )

    XCTAssertEqual(response.isFreeTrialAvailable, expectation.isFreeTrialAvailable)
    XCTAssertTrue(response.productVariables.isEmpty)
    XCTAssertTrue(response.swProductVariablesTemplate.isEmpty)
    XCTAssertTrue(response.orderedSwProducts.isEmpty)
  }

  func testGetVariablesAndFreeTrial_secondaryProduct() async {
    // Given
    let productId = "id1"
    let productType: ProductType = .secondary
    let products = [Product(
      type: productType,
      id: productId
    )]

    let product = StoreProduct(
      sk1Product:
        SKProduct(
          identifier: productId,
          price: "1.99"
        )
    )
    let productsById = [productId: product]

    // When
    let response = await PaywallLogic.getVariablesAndFreeTrial(
      fromProducts: products,
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: { product in return false }
    )

    // Then

    let expectedProductVariables = [ProductVariable(
      type: productType,
      attributes: product.attributesJson
    )]
    let expectedSwProductVariables = [ProductVariable(
      type: productType,
      attributes: product.swProductTemplateVariablesJson
    )]
    XCTAssertFalse(response.isFreeTrialAvailable)
    XCTAssertEqual(response.productVariables, expectedProductVariables)
    XCTAssertEqual(response.swProductVariablesTemplate, expectedSwProductVariables)
  }

  func testGetVariablesAndFreeTrial_primaryProductHasPurchased_noOverride() async {
    // Given
    let productId = "id1"
    let productType: ProductType = .primary
    let products = [Product(
      type: productType,
      id: productId
    )]
    let mockIntroPeriod = MockIntroductoryPeriod(
      testSubscriptionPeriod: MockSubscriptionPeriod()
    )

    let product = StoreProduct(
      sk1Product:
        SKProduct(
          identifier: productId,
          price: "1.99",
          introductoryPrice: mockIntroPeriod
        )
    )
    let productsById = [productId: product]

    
    // When
    let response = await PaywallLogic.getVariablesAndFreeTrial(
      fromProducts: products,
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: { _ in
        return false
      }
    )

    // Then
    let expectedProductVariables = [ProductVariable(
      type: productType,
      attributes: product.attributesJson
    )]
    let expectedSwProductVariables = [ProductVariable(
      type: productType,
      attributes: product.swProductTemplateVariablesJson
    )]

    XCTAssertFalse(response.isFreeTrialAvailable)
    XCTAssertEqual(response.productVariables, expectedProductVariables)
    XCTAssertEqual(response.swProductVariablesTemplate, expectedSwProductVariables)
  }

  func testGetVariablesAndFreeTrial_primaryProductHasntPurchased_noOverride() async {
    // Given
    let productId = "id1"
    let productType: ProductType = .primary
    let products = [Product(
      type: productType,
      id: productId
    )]
    let mockIntroPeriod = MockIntroductoryPeriod(
      testSubscriptionPeriod: MockSubscriptionPeriod()
    )
    let product = StoreProduct(
      sk1Product:
        SKProduct(
          identifier: productId,
          price: "1.99",
          introductoryPrice: mockIntroPeriod
        )
    )
    let productsById = [productId: product]

    // When
    let response = await PaywallLogic.getVariablesAndFreeTrial(
      fromProducts: products,
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: { _ in
        return true
      }
    )

    // Then
    let expectedVariables = [ProductVariable(
      type: productType,
      attributes: product.attributesJson
    )]
    let expectedProductVariables = [ProductVariable(
      type: productType,
      attributes: product.swProductTemplateVariablesJson
    )]

    XCTAssertTrue(response.isFreeTrialAvailable)
    XCTAssertEqual(response.productVariables, expectedVariables)
    XCTAssertEqual(response.swProductVariablesTemplate, expectedProductVariables)
  }

  func testGetVariablesAndFreeTrial_primaryProductHasPurchased_withOverride() async {
    // Given
    let productId = "id1"
    let productType: ProductType = .primary
    let products = [Product(
      type: productType,
      id: productId
    )]
    let mockIntroPeriod = MockIntroductoryPeriod(
      testSubscriptionPeriod: MockSubscriptionPeriod()
    )
    let product = StoreProduct(
      sk1Product:
        SKProduct(
          identifier: productId,
          price: "1.99",
          introductoryPrice: mockIntroPeriod
        )
    )
    let productsById = [productId: product]

    // When
    let response = await PaywallLogic.getVariablesAndFreeTrial(
      fromProducts: products,
      productsById: productsById,
      isFreeTrialAvailableOverride: true,
      isFreeTrialAvailable: { _ in
        return false
      }
    )

    // Then
    let expectedProductVariables = [ProductVariable(
      type: productType,
      attributes: product.attributesJson
    )]
    let expectedSwProductVariables = [ProductVariable(
      type: productType,
      attributes: product.swProductTemplateVariablesJson
    )]

    XCTAssertTrue(response.isFreeTrialAvailable)
    XCTAssertEqual(response.productVariables, expectedProductVariables)
    XCTAssertEqual(response.swProductVariablesTemplate, expectedSwProductVariables)
  }
}
