//
//  File.swift
//  
//
//  Created by Yusuf Tör on 18/01/2023.
// swiftlint:disable all

import XCTest
@testable import SuperwallKit
import StoreKit

final class TemplateLogicTests: XCTestCase {
  class MockVariablesFactory: VariablesFactory {
    let userAttributes: [String: Any]
    let deviceDict: [String: Any]?

    init(
      userAttributes: [String: Any],
      deviceDict: [String: Any]?
    ) {
      self.userAttributes = userAttributes
      self.deviceDict = deviceDict
    }

    func makeJsonVariables(productVariables: [ProductVariable]?, params: JSON?) -> JSON {
      return Variables(
        productVariables: productVariables,
        params: params,
        userAttributes: userAttributes,
        templateDeviceDictionary: deviceDict
      ).templated()
    }
  }

  func test_getBase64EncodedTemplates_oneProduct_noFreeTrial_userAttributes() {
    // MARK: Given
    let products = [Product(type: .primary, id: "123")]
    let productVariables = [ProductVariable(type: .primary, attributes: ["period": "month"])]
    let userAttributes = [
      "name": "Yusuf"
    ]
    let deviceDict = [
      "isMac": false
    ]
    let params: JSON = ["myparam": "test"]

    let factory = MockVariablesFactory(
      userAttributes: userAttributes,
      deviceDict: deviceDict
    )

    // MARK: When

    // Encode
    let encodedTemplates = TemplateLogic.getBase64EncodedTemplates(
      from: .stub()
        .setting(\.products, to: products)
        .setting(\.productVariables, to: productVariables),
      withParams: params,
      factory: factory
    )

    // decode
    let encodedData = Data(base64Encoded: encodedTemplates)!
    let json = try! JSON(data: encodedData)
    let jsonArray = json.array!

    // MARK: Then
    XCTAssertEqual(jsonArray[0]["event_name"], "products")
    XCTAssertEqual(jsonArray[0]["products"][0]["productId"].stringValue, products.first!.id)
    XCTAssertEqual(jsonArray[0]["products"][0]["product"].stringValue, products.first!.type.rawValue)
    XCTAssertEqual(jsonArray[0]["products"].count, 1)

    XCTAssertEqual(jsonArray[1]["event_name"], "template_variables")
    XCTAssertFalse(jsonArray[1]["variables"]["device"]["isMac"].boolValue)
    XCTAssertEqual(jsonArray[1]["variables"]["params"]["myparam"], "test")
    XCTAssertEqual(jsonArray[1]["variables"]["user"]["name"], "Yusuf")
    XCTAssertEqual(jsonArray[1]["variables"]["primary"]["period"], "month")
    XCTAssertEqual(jsonArray[1]["variables"]["primary"].count, 1)
    XCTAssertTrue(jsonArray[1]["variables"]["secondary"].isEmpty)
    XCTAssertTrue(jsonArray[1]["variables"]["tertiary"].isEmpty)


    XCTAssertEqual(jsonArray[2]["event_name"], "template_substitutions_prefix")
    XCTAssertEqual(jsonArray[2].count, 1)

    XCTAssertEqual(jsonArray[3]["event_name"], "template_product_variables")
    XCTAssertTrue(jsonArray[3]["variables"].isEmpty)
  }

  func test_getBase64EncodedTemplates_oneProduct_freeTrial_userAttributes() {
    // MARK: Given
    let products = [Product(type: .primary, id: "123")]
    let productVariables = [ProductVariable(type: .primary, attributes: ["period": "month"])]
    let userAttributes = [
      "name": "Yusuf"
    ]
    let deviceDict = [
      "isMac": false
    ]
    let params: JSON = ["myparam": "test"]

    let factory = MockVariablesFactory(
      userAttributes: userAttributes,
      deviceDict: deviceDict
    )

    // MARK: When

    // Encode
    let encodedTemplates = TemplateLogic.getBase64EncodedTemplates(
      from: .stub()
        .setting(\.products, to: products)
        .setting(\.productVariables, to: productVariables)
        .setting(\.isFreeTrialAvailable, to: true),
      withParams: params,
      factory: factory
    )

    // decode
    let encodedData = Data(base64Encoded: encodedTemplates)!
    let json = try! JSON(data: encodedData)
    let jsonArray = json.array!

    // MARK: Then
    XCTAssertEqual(jsonArray[0]["event_name"], "products")
    XCTAssertEqual(jsonArray[0]["products"][0]["productId"].stringValue, products.first!.id)
    XCTAssertEqual(jsonArray[0]["products"][0]["product"].stringValue, products.first!.type.rawValue)
    XCTAssertEqual(jsonArray[0]["products"].count, 1)

    XCTAssertEqual(jsonArray[1]["event_name"], "template_variables")
    XCTAssertFalse(jsonArray[1]["variables"]["device"]["isMac"].boolValue)
    XCTAssertEqual(jsonArray[1]["variables"]["params"]["myparam"], "test")
    XCTAssertEqual(jsonArray[1]["variables"]["user"]["name"], "Yusuf")
    XCTAssertEqual(jsonArray[1]["variables"]["primary"]["period"], "month")
    XCTAssertEqual(jsonArray[1]["variables"]["primary"].count, 1)
    XCTAssertTrue(jsonArray[1]["variables"]["secondary"].isEmpty)
    XCTAssertTrue(jsonArray[1]["variables"]["tertiary"].isEmpty)


    XCTAssertEqual(jsonArray[2]["event_name"], "template_substitutions_prefix")
    XCTAssertEqual(jsonArray[2]["prefix"], "freeTrial")

    XCTAssertEqual(jsonArray[3]["event_name"], "template_product_variables")
    XCTAssertTrue(jsonArray[3]["variables"].isEmpty)
  }

  func test_getBase64EncodedTemplates_threeProducts_freeTrial_userAttributes() {
    // MARK: Given
    let products = [
      Product(type: .primary, id: "123"),
      Product(type: .secondary, id: "456"),
      Product(type: .tertiary, id: "789"),
    ]
    let productVariables = [
      ProductVariable(type: .primary, attributes: ["period": "month"]),
      ProductVariable(type: .secondary, attributes: ["period": "month"]),
      ProductVariable(type: .tertiary, attributes: ["period": "month"])
    ]
    let userAttributes = [
      "name": "Yusuf"
    ]
    let deviceDict = [
      "isMac": false
    ]
    let params: JSON = ["myparam": "test"]

    let factory = MockVariablesFactory(
      userAttributes: userAttributes,
      deviceDict: deviceDict
    )

    // MARK: When

    // Encode
    let encodedTemplates = TemplateLogic.getBase64EncodedTemplates(
      from: .stub()
        .setting(\.products, to: products)
        .setting(\.productVariables, to: productVariables)
        .setting(\.isFreeTrialAvailable, to: true),
      withParams: params,
      factory: factory
    )

    // decode
    let encodedData = Data(base64Encoded: encodedTemplates)!
    let json = try! JSON(data: encodedData)
    let jsonArray = json.array!

    // MARK: Then
    XCTAssertEqual(jsonArray[0]["event_name"], "products")
    XCTAssertEqual(jsonArray[0]["products"][0]["productId"].stringValue, products.first!.id)
    XCTAssertEqual(jsonArray[0]["products"][0]["product"].stringValue, products.first!.type.rawValue)
    XCTAssertEqual(jsonArray[0]["products"][1]["productId"].stringValue, products[1].id)
    XCTAssertEqual(jsonArray[0]["products"][1]["product"].stringValue, products[1].type.rawValue)
    XCTAssertEqual(jsonArray[0]["products"][2]["productId"].stringValue, products[2].id)
    XCTAssertEqual(jsonArray[0]["products"][2]["product"].stringValue, products[2].type.rawValue)
    XCTAssertEqual(jsonArray[0]["products"].count, 3)

    XCTAssertEqual(jsonArray[1]["event_name"], "template_variables")
    XCTAssertFalse(jsonArray[1]["variables"]["device"]["isMac"].boolValue)
    XCTAssertEqual(jsonArray[1]["variables"]["params"]["myparam"], "test")
    XCTAssertEqual(jsonArray[1]["variables"]["user"]["name"], "Yusuf")
    XCTAssertEqual(jsonArray[1]["variables"]["primary"]["period"], "month")
    XCTAssertEqual(jsonArray[1]["variables"]["primary"].count, 1)
    XCTAssertEqual(jsonArray[1]["variables"]["secondary"]["period"], "month")
    XCTAssertEqual(jsonArray[1]["variables"]["secondary"].count, 1)
    XCTAssertEqual(jsonArray[1]["variables"]["tertiary"]["period"], "month")
    XCTAssertEqual(jsonArray[1]["variables"]["tertiary"].count, 1)


    XCTAssertEqual(jsonArray[2]["event_name"], "template_substitutions_prefix")
    XCTAssertEqual(jsonArray[2]["prefix"], "freeTrial")

    XCTAssertEqual(jsonArray[3]["event_name"], "template_product_variables")
    XCTAssertTrue(jsonArray[3]["variables"].isEmpty)
  }

  func test_getBase64EncodedTemplates_threeProducts_freeTrial_userAttributes_variablesTemplate() {
    // MARK: Given
    let products = [
      Product(type: .primary, id: "123"),
      Product(type: .secondary, id: "456"),
      Product(type: .tertiary, id: "789"),
    ]
    let productVariables = [
      ProductVariable(type: .primary, attributes: ["period": "month"]),
      ProductVariable(type: .secondary, attributes: ["period": "month"]),
      ProductVariable(type: .tertiary, attributes: ["period": "month"])
    ]
    let swProductVariablesTemplate = [
      ProductVariable(type: .primary, attributes: ["period": "month"])
    ]
    let userAttributes = [
      "name": "Yusuf"
    ]
    let deviceDict = [
      "isMac": false
    ]
    let params: JSON = ["myparam": "test"]

    let factory = MockVariablesFactory(
      userAttributes: userAttributes,
      deviceDict: deviceDict
    )

    // MARK: When

    // Encode
    let encodedTemplates = TemplateLogic.getBase64EncodedTemplates(
      from: .stub()
        .setting(\.products, to: products)
        .setting(\.productVariables, to: productVariables)
        .setting(\.isFreeTrialAvailable, to: true)
        .setting(\.swProductVariablesTemplate, to: swProductVariablesTemplate),
      withParams: params,
      factory: factory
    )

    // decode
    let encodedData = Data(base64Encoded: encodedTemplates)!
    let json = try! JSON(data: encodedData)
    let jsonArray = json.array!

    // MARK: Then
    XCTAssertEqual(jsonArray[0]["event_name"], "products")
    XCTAssertEqual(jsonArray[0]["products"][0]["productId"].stringValue, products.first!.id)
    XCTAssertEqual(jsonArray[0]["products"][0]["product"].stringValue, products.first!.type.rawValue)
    XCTAssertEqual(jsonArray[0]["products"][1]["productId"].stringValue, products[1].id)
    XCTAssertEqual(jsonArray[0]["products"][1]["product"].stringValue, products[1].type.rawValue)
    XCTAssertEqual(jsonArray[0]["products"][2]["productId"].stringValue, products[2].id)
    XCTAssertEqual(jsonArray[0]["products"][2]["product"].stringValue, products[2].type.rawValue)
    XCTAssertEqual(jsonArray[0]["products"].count, 3)

    XCTAssertEqual(jsonArray[1]["event_name"], "template_variables")
    XCTAssertFalse(jsonArray[1]["variables"]["device"]["isMac"].boolValue)
    XCTAssertEqual(jsonArray[1]["variables"]["params"]["myparam"], "test")
    XCTAssertEqual(jsonArray[1]["variables"]["user"]["name"], "Yusuf")
    XCTAssertEqual(jsonArray[1]["variables"]["primary"]["period"], "month")
    XCTAssertEqual(jsonArray[1]["variables"]["primary"].count, 1)
    XCTAssertEqual(jsonArray[1]["variables"]["secondary"]["period"], "month")
    XCTAssertEqual(jsonArray[1]["variables"]["secondary"].count, 1)
    XCTAssertEqual(jsonArray[1]["variables"]["tertiary"]["period"], "month")
    XCTAssertEqual(jsonArray[1]["variables"]["tertiary"].count, 1)


    XCTAssertEqual(jsonArray[2]["event_name"], "template_substitutions_prefix")
    XCTAssertEqual(jsonArray[2]["prefix"], "freeTrial")

    XCTAssertEqual(jsonArray[3]["event_name"], "template_product_variables")
    XCTAssertEqual(jsonArray[3]["variables"]["primary"]["period"], "month")
    XCTAssertEqual(jsonArray[3]["variables"].count, 1)
  }
}
