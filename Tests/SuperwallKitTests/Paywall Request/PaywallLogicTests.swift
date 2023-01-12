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
      locale: locale
    )

    // Then
    XCTAssertEqual(hash, "\(id)_\(locale)")
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
      locale: locale
    )

    // Then
    XCTAssertEqual(hash, "\(id)_\(locale)")
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
      locale: locale
    )

    // Then
    XCTAssertEqual(hash, "\(eventName)_\(locale)")
  }

  func testRequestHash_noIdentifierNoEvent() {
    // Given
    let locale = "en_US"

    // When
    let hash = PaywallLogic.requestHash(
      locale: locale
    )

    // Then
    XCTAssertEqual(hash, "$called_manually_\(locale)")
  }

  // MARK: - getVariablesAndFreeTrial
  func testGetVariablesAndFreeTrial_noProducts() {
    let response = PaywallLogic.getVariablesAndFreeTrial(
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

  func testGetVariablesAndFreeTrial_productNotFound() {
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
    
    let response = PaywallLogic.getVariablesAndFreeTrial(
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

  func testGetVariablesAndFreeTrial_secondaryProduct() {
    // Given
    let productId = "id1"
    let productType: ProductType = .secondary
    let products = [Product(
      type: productType,
      id: productId
    )]

    let skProduct = SKProduct(
      identifier: productId,
      price: "1.99"
    )
    let productsById = [productId: StoreProduct(sk1Product: skProduct)]

    // When
    let response = PaywallLogic.getVariablesAndFreeTrial(
      fromProducts: products,
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      isFreeTrialAvailable: { product in return false }
    )

    // Then

    let expectedProductVariables = [ProductVariable(
      type: productType,
      attributes: skProduct.attributesJson
    )]
    let expectedSwProductVariables = [ProductVariable(
      type: productType,
      attributes: skProduct.swProductTemplateVariablesJson
    )]
    XCTAssertFalse(response.isFreeTrialAvailable)
    XCTAssertEqual(response.productVariables, expectedProductVariables)
    XCTAssertEqual(response.swProductVariablesTemplate, expectedSwProductVariables)
  }

  func testGetVariablesAndFreeTrial_primaryProductHasPurchased_noOverride() {
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
    let skProduct = SKProduct(
      identifier: productId,
      price: "1.99",
      introductoryPrice: mockIntroPeriod
    )
    let productsById = [productId: StoreProduct(sk1Product: skProduct)]

    
    // When
    let response = PaywallLogic.getVariablesAndFreeTrial(
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
      attributes: skProduct.attributesJson
    )]
    let expectedSwProductVariables = [ProductVariable(
      type: productType,
      attributes: skProduct.swProductTemplateVariablesJson
    )]

    XCTAssertFalse(response.isFreeTrialAvailable)
    XCTAssertEqual(response.productVariables, expectedProductVariables)
    XCTAssertEqual(response.swProductVariablesTemplate, expectedSwProductVariables)
  }

  func testGetVariablesAndFreeTrial_primaryProductHasntPurchased_noOverride() {
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
    let skProduct = SKProduct(
      identifier: productId,
      price: "1.99",
      introductoryPrice: mockIntroPeriod
    )
    let productsById = [productId: StoreProduct(sk1Product: skProduct)]

    // When
    let response = PaywallLogic.getVariablesAndFreeTrial(
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
      attributes: skProduct.attributesJson
    )]
    let expectedProductVariables = [ProductVariable(
      type: productType,
      attributes: skProduct.swProductTemplateVariablesJson
    )]

    XCTAssertTrue(response.isFreeTrialAvailable)
    XCTAssertEqual(response.productVariables, expectedVariables)
    XCTAssertEqual(response.swProductVariablesTemplate, expectedProductVariables)
  }

  func testGetVariablesAndFreeTrial_primaryProductHasPurchased_withOverride() {
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
    let skProduct = SKProduct(
      identifier: productId,
      price: "1.99",
      introductoryPrice: mockIntroPeriod
    )
    let productsById = [productId: StoreProduct(sk1Product: skProduct)]

    // When
    let response = PaywallLogic.getVariablesAndFreeTrial(
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
      attributes: skProduct.attributesJson
    )]
    let expectedSwProductVariables = [ProductVariable(
      type: productType,
      attributes: skProduct.swProductTemplateVariablesJson
    )]

    XCTAssertTrue(response.isFreeTrialAvailable)
    XCTAssertEqual(response.productVariables, expectedProductVariables)
    XCTAssertEqual(response.swProductVariablesTemplate, expectedSwProductVariables)
  }
}
