//
//  PaywallResponseLogicTests.swift
//  
//
//  Created by Yusuf Tör on 17/03/2022.
//
// swiftlint:disable all

import XCTest
@testable import Paywall

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

  // MARK: - Request Hash
  func testHandleTriggerResponse_didNotFetchConfig_noPaywallId() {
    // When
    let outcome = try? PaywallResponseLogic.handleTriggerResponse(
      withPaywallId: nil,
      fromEvent: nil,
      didFetchConfig: false
    )

    // Then
    let expectedOutcome = TriggerResponseIdentifiers(
      paywallId: nil,
      experimentId: nil,
      variantId: nil
    )

    XCTAssertEqual(outcome, expectedOutcome)
  }

  func testHandleTriggerResponse_didNotFetchConfig_hasPaywallId() {
    // Given
    let paywallId = "myid"

    // When
    let outcome = try? PaywallResponseLogic.handleTriggerResponse(
      withPaywallId: paywallId,
      fromEvent: nil,
      didFetchConfig: false
    )

    // Then
    let expectedOutcome = TriggerResponseIdentifiers(
      paywallId: paywallId,
      experimentId: nil,
      variantId: nil
    )

    XCTAssertEqual(outcome, expectedOutcome)
  }

  func testHandleTriggerResponse_didFetchConfig_noEvent_noPaywallId() {
    // When
    let outcome = try? PaywallResponseLogic.handleTriggerResponse(
      withPaywallId: nil,
      fromEvent: nil,
      didFetchConfig: true
    )

    // Then
    let expectedOutcome = TriggerResponseIdentifiers(
      paywallId: nil,
      experimentId: nil,
      variantId: nil
    )

    XCTAssertEqual(outcome, expectedOutcome)
  }

  func testHandleTriggerResponse_didFetchConfig_noEvent_hasPaywallId() {
    // Given
    let paywallId = "myid"

    // When
    let outcome = try? PaywallResponseLogic.handleTriggerResponse(
      withPaywallId: paywallId,
      fromEvent: nil,
      didFetchConfig: true
    )

    // Then
    let expectedOutcome = TriggerResponseIdentifiers(
      paywallId: paywallId,
      experimentId: nil,
      variantId: nil
    )

    XCTAssertEqual(outcome, expectedOutcome)
  }

  func testHandleTriggerResponse_v1Trigger_hasPaywallId() {
    // Given
    let paywallId = "myid"
    let getTriggerResponse: (EventData) -> HandleEventResult = { _ in
      return .presentV1
    }

    // When
    let outcome = try? PaywallResponseLogic.handleTriggerResponse(
      withPaywallId: paywallId,
      fromEvent: .stub(),
      didFetchConfig: true,
      handleEvent: getTriggerResponse
    )

    // Then
    let expectedOutcome = TriggerResponseIdentifiers(
      paywallId: paywallId,
      experimentId: nil,
      variantId: nil
    )

    XCTAssertEqual(outcome, expectedOutcome)
  }

  func testHandleTriggerResponse_v1Trigger_noPaywallId() {
    // Given
    let getTriggerResponse: (EventData) -> HandleEventResult = { _ in
      return .presentV1
    }

    // When
    let outcome = try? PaywallResponseLogic.handleTriggerResponse(
      withPaywallId: nil,
      fromEvent: .stub(),
      didFetchConfig: true,
      handleEvent: getTriggerResponse
    )

    // Then
    let expectedOutcome = TriggerResponseIdentifiers(
      paywallId: nil,
      experimentId: nil,
      variantId: nil
    )

    XCTAssertEqual(outcome, expectedOutcome)
  }

  func testHandleTriggerResponse_presentV2() {
    // TODO: We can't have it when paywallIdentifier is nil, why?

    // Given
    let experimentId = "expId"
    let variantId = "varId"
    let paywallId = "paywallId"
    let getTriggerResponse: (EventData) -> HandleEventResult = { _ in
      return .presentV2(
        experimentId: experimentId,
        variantId: variantId,
        paywallIdentifier: paywallId
      )
    }

    // When
    let outcome = try? PaywallResponseLogic.handleTriggerResponse(
      withPaywallId: paywallId,
      fromEvent: .stub(),
      didFetchConfig: true,
      handleEvent: getTriggerResponse
    )

    // Then
    let expectedOutcome = TriggerResponseIdentifiers(
      paywallId: paywallId,
      experimentId: experimentId,
      variantId: variantId
    )

    XCTAssertEqual(outcome, expectedOutcome)
  }

  func testHandleTriggerResponse_holdout() {
    // Given
    let experimentId = "expId"
    let variantId = "varId"
    let paywallId = "paywallId"
    let getTriggerResponse: (EventData) -> HandleEventResult = { _ in
      return .holdout(
        experimentId: experimentId,
        variantId: variantId
      )
    }

    // When
    do {
      _ = try PaywallResponseLogic.handleTriggerResponse(
        withPaywallId: paywallId,
        fromEvent: .stub(),
        didFetchConfig: true,
        handleEvent: getTriggerResponse
      )
    } catch let error as NSError {
      // Then

      let userInfo: [String: Any] = [
        "experimentId": experimentId,
        "variantId": variantId,
        NSLocalizedDescriptionKey: NSLocalizedString(
          "Trigger Holdout",
          value: "This user was assigned to a holdout in a trigger experiment",
          comment: "ExperimentId: \(experimentId), VariantId: \(variantId)"
        )
      ]
      let expectedError = NSError(
        domain: "com.superwall",
        code: 4001,
        userInfo: userInfo
      )
      XCTAssertEqual(error, expectedError)
    }
  }

  func testHandleTriggerResponse_noRuleMatch() {
    // Given
    let getTriggerResponse: (EventData) -> HandleEventResult = { _ in
      return .noRuleMatch
    }

    // When
    do {
      _ = try PaywallResponseLogic.handleTriggerResponse(
        withPaywallId: nil,
        fromEvent: .stub(),
        didFetchConfig: true,
        handleEvent: getTriggerResponse
      )
    } catch let error as NSError {
      // Then

      let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: NSLocalizedString(
          "No rule match",
          value: "The user did not match any rules configured for this trigger",
          comment: ""
        )
      ]
      let expectedError = NSError(
        domain: "com.superwall",
        code: 4000,
        userInfo: userInfo
      )
      XCTAssertEqual(error, expectedError)
    }
  }
}
