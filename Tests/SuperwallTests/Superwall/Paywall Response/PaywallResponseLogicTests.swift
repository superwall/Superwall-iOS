//
//  PaywallResponseLogicTests.swift
//  
//
//  Created by Yusuf Tör on 17/03/2022.
//
// swiftlint:disable all

import XCTest
@testable import Superwall
import StoreKit

@available(iOS 14.0, *)
class PaywallResponseLogicTests: XCTestCase {
  // MARK: - Request Hash
  func testRequestHash_withIdentifierNoEvent() {
    // Given
    let id = "myid"
    let locale = "en_US"

    // When
    let hash = PaywallResponseLogic.requestHash(
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
    let hash = PaywallResponseLogic.requestHash(
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
    let hash = PaywallResponseLogic.requestHash(
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
    let hash = PaywallResponseLogic.requestHash(
      locale: locale
    )

    // Then
    XCTAssertEqual(hash, "$called_manually_\(locale)")
  }

  // MARK: - TriggerResultOutcome
  func testTriggerResultOutcome_presentPaywall() {
    // Given
    let experimentId = "expId"
    let experimentGroupId = "groupId"
    let paywallId = "paywallId"
    let eventName = "blah"

    let variantOption = VariantOption.stub()
      .setting(\.type, to: .treatment)
      .setting(\.paywallId, to: paywallId)
    let rawExperiment = RawExperiment.stub()
      .setting(\.id, to: experimentId)
      .setting(\.groupId, to: experimentGroupId)
      .setting(\.variants, to: [variantOption])

    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: nil,
      expressionJs: nil
    )
    let trigger = Trigger(
      eventName: eventName,
      rules: [triggerRule]
    )

    let configManager = ConfigManagerMock()
    configManager.unconfirmedAssignments = [experimentId: variantOption.toVariant()]

    // When
    let outcome = PaywallResponseLogic.getTriggerResultAndConfirmAssignment(
      presentationInfo: .explicitTrigger(.stub().setting(\.name, to: eventName)),
      configManager: configManager,
      triggers: [eventName: trigger]
    )

    // Then
    let expectedExperiment = Experiment(
      id: experimentId,
      groupId: experimentGroupId,
      variant: variantOption.toVariant()
    )
    let expectedIdentifiers = ResponseIdentifiers(
      paywallId: paywallId,
      experiment: expectedExperiment
    )

    guard case let .paywall(identifiers) = outcome.info else {
      return XCTFail()
    }

    XCTAssertEqual(identifiers, expectedIdentifiers)

    guard case let .paywall(experiment: returnedExperiment) = outcome.result else {
      return XCTFail()
    }
    XCTAssertTrue(configManager.confirmedAssignment)
    XCTAssertEqual(expectedExperiment, returnedExperiment)
  }

  func testTriggerResultOutcome_holdout() {
    // Given
    let experimentId = "expId"
    let experimentGroupId = "groupId"
    let variantId = "varId"
    let eventName = "opened_application"

    let variantOption = VariantOption.stub()
      .setting(\.type, to: .holdout)
      .setting(\.id, to: variantId)
    let rawExperiment = RawExperiment.stub()
      .setting(\.id, to: experimentId)
      .setting(\.groupId, to: experimentGroupId)
      .setting(\.variants, to: [variantOption]
    )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: nil,
      expressionJs: nil
    )
    let trigger = Trigger(
      eventName: eventName,
      rules: [triggerRule]
    )

    let configManager = ConfigManagerMock()
    configManager.unconfirmedAssignments = [experimentId: variantOption.toVariant()]

    // When
    let outcome = PaywallResponseLogic.getTriggerResultAndConfirmAssignment(
      presentationInfo: .explicitTrigger(.stub().setting(\.name, to: eventName)),
      configManager: configManager,
      triggers: [eventName: trigger]
    )

    // Then
    let expectedExperiment = Experiment(
      id: experimentId,
      groupId: experimentGroupId,
      variant: variantOption.toVariant()
    )
    guard case let .holdout(experiment) = outcome.info else {
      return XCTFail()
    }

    XCTAssertEqual(expectedExperiment, experiment)
    XCTAssertTrue(configManager.confirmedAssignment)
  }

  func testGetTriggerIdentifiers_noRuleMatch() {
    // Given
    let experimentId = "expId"
    let experimentGroupId = "groupId"
    let eventName = "opened_application"

    let variantOption = VariantOption.stub()
      .setting(\.type, to: .holdout)
    let rawExperiment = RawExperiment.stub()
      .setting(\.id, to: experimentId)
      .setting(\.groupId, to: experimentGroupId)
      .setting(\.variants, to: [variantOption]
    )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: "user.a == c",
      expressionJs: nil
    )
    let trigger = Trigger(
      eventName: eventName,
      rules: [triggerRule]
    )

    let configManager = ConfigManagerMock()
    configManager.unconfirmedAssignments = [experimentId: variantOption.toVariant()]

    // When
    let outcome = PaywallResponseLogic.getTriggerResultAndConfirmAssignment(
      presentationInfo: .explicitTrigger(.stub().setting(\.name, to: eventName)),
      configManager: configManager,
      triggers: [eventName: trigger]
    )

    // Then
    guard case .noRuleMatch = outcome.info else {
      return XCTFail()
    }
    XCTAssertFalse(configManager.confirmedAssignment)
  }

  func testGetTriggerIdentifiers_unknownEvent() {
    // Given
    let experimentId = "expId"
    let experimentGroupId = "groupId"
    let eventName = "opened_application"

    let variantOption = VariantOption.stub()
      .setting(\.type, to: .holdout)
    let rawExperiment = RawExperiment.stub()
      .setting(\.id, to: experimentId)
      .setting(\.groupId, to: experimentGroupId)
      .setting(\.variants, to: [variantOption]
    )
    let triggerRule = TriggerRule(
      experiment: rawExperiment,
      expression: nil,
      expressionJs: nil
    )
    let trigger = Trigger(
      eventName: "other",
      rules: [triggerRule]
    )

    let configManager = ConfigManagerMock()

    // When
    let outcome = PaywallResponseLogic.getTriggerResultAndConfirmAssignment(
      presentationInfo: .explicitTrigger(.stub().setting(\.name, to: eventName)),
      configManager: configManager,
      triggers: [eventName: trigger]
    )

    guard case let .error(error) = outcome.info else {
      return XCTFail()
    }

    let userInfo: [String: Any] = [
      NSLocalizedDescriptionKey: NSLocalizedString(
        "Not Found",
        value: "There isn't a paywall configured to show in this context",
        comment: ""
      )
    ]
    let expectedError = NSError(
      domain: "SWPaywallNotFound",
      code: 404,
      userInfo: userInfo
    )
    XCTAssertEqual(error, expectedError)

    guard case .error(let error) = outcome.result else {
      return XCTFail()
    }
    XCTAssertEqual(error, expectedError)
    XCTAssertFalse(configManager.confirmedAssignment)
  }

  // MARK: - getVariablesAndFreeTrial
  func testGetVariablesAndFreeTrial_noProducts() {
    let response = PaywallResponseLogic.getVariablesAndFreeTrial(
      fromProducts: [],
      productsById: [:],
      isFreeTrialAvailableOverride: nil
    )

    let expectation = ProductProcessingOutcome(
      variables: [],
      productVariables: [],
      orderedSwProducts: [],
      isFreeTrialAvailable: nil,
      resetFreeTrialOverride: false
    )

    XCTAssertEqual(response.isFreeTrialAvailable, expectation.isFreeTrialAvailable)
    XCTAssertTrue(response.variables.isEmpty)
    XCTAssertEqual(response.resetFreeTrialOverride, expectation.resetFreeTrialOverride)
    XCTAssertTrue(response.productVariables.isEmpty)
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
    let productsById = [skProductId: skProduct]
    
    let response = PaywallResponseLogic.getVariablesAndFreeTrial(
      fromProducts: products,
      productsById: productsById,
      isFreeTrialAvailableOverride: nil
    )

    let expectation = ProductProcessingOutcome(
      variables: [],
      productVariables: [],
      orderedSwProducts: [],
      isFreeTrialAvailable: nil,
      resetFreeTrialOverride: false
    )

    XCTAssertEqual(response.isFreeTrialAvailable, expectation.isFreeTrialAvailable)
    XCTAssertTrue(response.variables.isEmpty)
    XCTAssertEqual(response.resetFreeTrialOverride, expectation.resetFreeTrialOverride)
    XCTAssertTrue(response.productVariables.isEmpty)
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
    let productsById = [productId: skProduct]

    // When
    let response = PaywallResponseLogic.getVariablesAndFreeTrial(
      fromProducts: products,
      productsById: productsById,
      isFreeTrialAvailableOverride: nil
    )

    // Then

    let expectedVariables = [Variable(
      key: productType.rawValue,
      value: skProduct.eventData
    )]
    let expectedProductVariables = [ProductVariable(
      key: productType.rawValue,
      value: skProduct.productVariables
    )]
    XCTAssertNil(response.isFreeTrialAvailable)
    XCTAssertEqual(response.variables, expectedVariables)
    XCTAssertFalse(response.resetFreeTrialOverride)
    XCTAssertEqual(response.productVariables, expectedProductVariables)
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
    let productsById = [productId: skProduct]

    
    // When
    let response = PaywallResponseLogic.getVariablesAndFreeTrial(
      fromProducts: products,
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      hasPurchased: { _ in
        return true
      }
    )

    // Then
    let expectedVariables = [Variable(
      key: productType.rawValue,
      value: skProduct.eventData
    )]
    let expectedProductVariables = [ProductVariable(
      key: productType.rawValue,
      value: skProduct.productVariables
    )]

    guard let freeTrialAvailable = response.isFreeTrialAvailable else {
      return XCTFail()
    }
    XCTAssertFalse(freeTrialAvailable)
    XCTAssertEqual(response.variables, expectedVariables)
    XCTAssertFalse(response.resetFreeTrialOverride)
    XCTAssertEqual(response.productVariables, expectedProductVariables)
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
    let productsById = [productId: skProduct]

    // When
    let response = PaywallResponseLogic.getVariablesAndFreeTrial(
      fromProducts: products,
      productsById: productsById,
      isFreeTrialAvailableOverride: nil,
      hasPurchased: { _ in
        return false
      }
    )

    // Then
    let expectedVariables = [Variable(
      key: productType.rawValue,
      value: skProduct.eventData
    )]
    let expectedProductVariables = [ProductVariable(
      key: productType.rawValue,
      value: skProduct.productVariables
    )]

    guard let freeTrialAvailable = response.isFreeTrialAvailable else {
      return XCTFail()
    }
    XCTAssertTrue(freeTrialAvailable)
    XCTAssertEqual(response.variables, expectedVariables)
    XCTAssertFalse(response.resetFreeTrialOverride)
    XCTAssertEqual(response.productVariables, expectedProductVariables)
  }

  func testGetVariablesAndFreeTrial_primaryProductHasntPurchased_withOverride() {
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
    let productsById = [productId: skProduct]

    // When
    let response = PaywallResponseLogic.getVariablesAndFreeTrial(
      fromProducts: products,
      productsById: productsById,
      isFreeTrialAvailableOverride: true,
      hasPurchased: { _ in
        return true
      }
    )

    // Then
    let expectedVariables = [Variable(
      key: productType.rawValue,
      value: skProduct.eventData
    )]
    let expectedProductVariables = [ProductVariable(
      key: productType.rawValue,
      value: skProduct.productVariables
    )]

    guard let freeTrialAvailable = response.isFreeTrialAvailable else {
      return XCTFail()
    }
    XCTAssertTrue(freeTrialAvailable)
    XCTAssertEqual(response.variables, expectedVariables)
    XCTAssertTrue(response.resetFreeTrialOverride)
    XCTAssertEqual(response.productVariables, expectedProductVariables)
  }
}
