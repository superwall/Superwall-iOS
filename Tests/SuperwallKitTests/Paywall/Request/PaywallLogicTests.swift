//
//  PaywallLogicTests.swift
//
//
//  Created by Yusuf Tör on 17/03/2022.
//
// swiftlint:disable all

import Testing
@testable import SuperwallKit
import StoreKit

struct PaywallLogicTests {
  // MARK: - Request Hash
  @Test
  func requestHash_withIdentifierNoEvent() {
    // Given
    let id = "myid"
    let locale = "en_US"

    // When
    let hash = PaywallLogic.requestHash(
      identifier: id,
      locale: locale,
      joinedSubstituteProductIds: nil
    )

    // Then
    #expect(hash == "\(id)_\(locale)_")
  }

  @Test
  func requestHash_withIdentifierWithEvent() {
    // Given
    let id = "myid"
    let locale = "en_US"
    let event: PlacementData = .stub()

    // When
    let hash = PaywallLogic.requestHash(
      identifier: id,
      placement: event,
      locale: locale,
      joinedSubstituteProductIds: nil
    )

    // Then
    #expect(hash == "\(id)_\(locale)_")
  }

  @Test
  func requestHash_withIdentifierWithEventAndProducts() {
    // Given
    let id = "myid"
    let locale = "en_US"
    let event: PlacementData = .stub()
    let product1 = StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: "abc"),
      entitlements: []
    )
    let product2 = StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: "def"),
      entitlements: []
    )
    let ids = ["abc", "def"].joined()

    // When
    let hash = PaywallLogic.requestHash(
      identifier: id,
      placement: event,
      locale: locale,
      joinedSubstituteProductIds: ids
    )

    // Then
    #expect(hash == "\(id)_\(locale)_abcdef")
  }

  @Test
  func requestHash_noIdentifierWithEvent() {
    // Given
    let locale = "en_US"
    let eventName = "MyEvent"
    let event: PlacementData = .stub()
      .setting(\.name, to: eventName)

    // When
    let hash = PaywallLogic.requestHash(
      placement: event,
      locale: locale,
      joinedSubstituteProductIds: nil
    )

    // Then
    #expect(hash == "\(eventName)_\(locale)_")
  }

  @Test
  func requestHash_noIdentifierNoEvent() {
    // Given
    let locale = "en_US"

    // When
    let hash = PaywallLogic.requestHash(
      locale: locale,
      joinedSubstituteProductIds: nil
    )

    // Then
    #expect(hash == "$called_manually_\(locale)_")
  }

  @Test
  func requestHash_noIdentifierWithEventAndProducts() {
    // Given
    let locale = "en_US"
    let eventName = "MyEvent"
    let event: PlacementData = .stub()
      .setting(\.name, to: eventName)
    let product1 = StoreProduct(
      sk1Product: MockSkProduct(productIdentifier: "abc"),
      entitlements: []
    )
    let ids = "abc"

    // When
    let hash = PaywallLogic.requestHash(
      placement: event,
      locale: locale,
      joinedSubstituteProductIds: ids
    )

    // Then
    #expect(hash == "\(eventName)_\(locale)_abc")
  }

  // MARK: - getProductVariables
  @Test
  func getProductVariables_noProducts() {
    let response = PaywallLogic.getProductVariables(
      productItems: [],
      productsById: [:]
    )

    #expect(response.productVariables.isEmpty)
    #expect(response.swProducts.isEmpty)
  }

  @Test
  func getProductVariables_productNotFound() {
    let productId = "id1"
    let products = [Product(
      name: "primary",
      type: .appStore(.init(id: productId)),
      id: productId,
      entitlements: []
    )]

    let skProductId = "id2"
    let skProduct = MockSkProduct(
      productIdentifier: skProductId,
      price: 1.99
    )
    let productsById = [skProductId: StoreProduct(sk1Product: skProduct, entitlements: [])]

    let response = PaywallLogic.getProductVariables(
      productItems: products,
      productsById: productsById
    )

    #expect(response.productVariables.isEmpty)
    #expect(response.swProducts.isEmpty)
  }

  @Test
  func getProductVariables_secondaryProduct() {
    // Given
    let productId = "id1"
    let products = [Product(
      name: "secondary",
      type: .appStore(.init(id: productId)),
      id: productId,
      entitlements: []
    )]

    let product = StoreProduct(
      sk1Product:
        MockSkProduct(
          productIdentifier: productId,
          price: 1.99
        ),
      entitlements: []
    )
    let productsById = [productId: product]

    // When
    let response = PaywallLogic.getProductVariables(
      productItems: products,
      productsById: productsById
    )

    // Then
    let expectedProductVariables = [ProductVariable(
      name: "secondary",
      attributes: product.attributesJson,
      id: productId,
      hasIntroOffer: false
    )]
    #expect(response.productVariables == expectedProductVariables)
  }

  @Test
  func getProductVariables_primaryProductWithIntroOffer() {
    // Given
    let productId = "id1"
    let products = [Product(
      name: "primary",
      type: .appStore(.init(id: productId)),
      id: productId,
      entitlements: []
    )]
    let mockIntroPeriod = MockIntroductoryPeriod(
      testSubscriptionPeriod: MockSubscriptionPeriod()
    )

    let product = StoreProduct(
      sk1Product:
        MockSkProduct(
          productIdentifier: productId,
          introPeriod: mockIntroPeriod,
          price: 1.99
        ),
      entitlements: []
    )
    let productsById = [productId: product]

    // When
    let response = PaywallLogic.getProductVariables(
      productItems: products,
      productsById: productsById
    )

    // Then
    let expectedProductVariables = [ProductVariable(
      name: "primary",
      attributes: product.attributesJson,
      id: productId,
      hasIntroOffer: true
    )]
    #expect(response.productVariables == expectedProductVariables)
  }
}
