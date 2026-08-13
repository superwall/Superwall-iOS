//
//  TemplateLogicFreeTrialAvailabilityTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 13/08/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Tests that per-product free trial availability is injected into the
/// product variables passed to the paywall webview.
struct TemplateLogicFreeTrialAvailabilityTests {
  class MockVariablesFactory: VariablesFactory {
    let userAttributes: [String: Any]
    let deviceDict: [String: Any]?

    init(
      userAttributes: [String: Any] = [:],
      deviceDict: [String: Any]? = nil
    ) {
      self.userAttributes = userAttributes
      self.deviceDict = deviceDict
    }

    func makeJsonVariables(
      products productVariables: [ProductVariable]?,
      computedPropertyRequests: [ComputedPropertyRequest],
      placement: PlacementData?
    ) async -> JSON {
      return Variables(
        products: productVariables,
        params: placement?.parameters,
        userAttributes: userAttributes,
        templateDeviceDictionary: deviceDict
      ).templated()
    }
  }

  private func decodeTemplates(_ encodedTemplates: String) throws -> JSON {
    let encodedData = try #require(Data(base64Encoded: encodedTemplates))
    return try JSON(data: encodedData)
  }

  @Test
  func injectsPerProductFreeTrialAvailability() async throws {
    let dependencyContainer = DependencyContainer()
    let products = [
      SuperwallKit.Product(
        name: "primary",
        type: .appStore(.init(id: "123")),
        id: "123",
        entitlements: [.stub()]
      ),
      SuperwallKit.Product(
        name: "secondary",
        type: .appStore(.init(id: "456")),
        id: "456",
        entitlements: [.stub()]
      )
    ]
    let productVariables = [
      ProductVariable(name: "primary", attributes: ["period": "month"], id: "123", hasIntroOffer: true),
      ProductVariable(name: "secondary", attributes: ["period": "year"], id: "456", hasIntroOffer: true)
    ]

    let encodedTemplates = await TemplateLogic.getBase64EncodedTemplates(
      from: .stub()
        .setting(\.products, to: products)
        .setting(\.productVariables, to: productVariables)
        .setting(\.isFreeTrialAvailableByProductName, to: ["primary": true, "secondary": false]),
      placement: nil,
      receiptManager: dependencyContainer.receiptManager,
      factory: MockVariablesFactory()
    )

    let json = try decodeTemplates(encodedTemplates)
    let productsJson = json[1]["variables"]["products"]

    #expect(productsJson[0]["primary"]["isFreeTrialAvailable"].bool == true)
    #expect(productsJson[1]["secondary"]["isFreeTrialAvailable"].bool == false)

    // period + isSubscribed + isFreeTrialAvailable
    #expect(productsJson[0]["primary"].count == 3)
    #expect(productsJson[1]["secondary"].count == 3)
  }

  @Test
  func omitsFreeTrialAvailability_whenNotComputedForProduct() async throws {
    let dependencyContainer = DependencyContainer()
    let products = [
      SuperwallKit.Product(
        name: "primary",
        type: .appStore(.init(id: "123")),
        id: "123",
        entitlements: [.stub()]
      )
    ]
    let productVariables = [
      ProductVariable(name: "primary", attributes: ["period": "month"], id: "123", hasIntroOffer: false)
    ]

    let encodedTemplates = await TemplateLogic.getBase64EncodedTemplates(
      from: .stub()
        .setting(\.products, to: products)
        .setting(\.productVariables, to: productVariables),
      placement: nil,
      receiptManager: dependencyContainer.receiptManager,
      factory: MockVariablesFactory()
    )

    let json = try decodeTemplates(encodedTemplates)
    let productsJson = json[1]["variables"]["products"]

    #expect(productsJson[0]["primary"]["isFreeTrialAvailable"].bool == nil)

    // period + isSubscribed only
    #expect(productsJson[0]["primary"].count == 2)
  }

  @Test
  func injectsFreeTrialAvailability_forCustomProducts() async throws {
    let dependencyContainer = DependencyContainer()
    let products = [
      SuperwallKit.Product(
        name: "primary",
        type: .custom(.init(id: "custom_1")),
        id: "custom_1",
        entitlements: [.stub()]
      )
    ]
    let productVariables = [
      ProductVariable(name: "primary", attributes: ["period": "month"], id: "custom_1", hasIntroOffer: true)
    ]

    let encodedTemplates = await TemplateLogic.getBase64EncodedTemplates(
      from: .stub()
        .setting(\.products, to: products)
        .setting(\.productVariables, to: productVariables)
        .setting(\.isFreeTrialAvailableByProductName, to: ["primary": true]),
      placement: nil,
      receiptManager: dependencyContainer.receiptManager,
      factory: MockVariablesFactory()
    )

    let json = try decodeTemplates(encodedTemplates)
    let productsJson = json[1]["variables"]["products"]

    #expect(productsJson[0]["primary"]["isFreeTrialAvailable"].bool == true)

    // Custom products don't get isSubscribed, so: period + isFreeTrialAvailable
    #expect(productsJson[0]["primary"]["isSubscribed"].bool == nil)
    #expect(productsJson[0]["primary"].count == 2)
  }
}
