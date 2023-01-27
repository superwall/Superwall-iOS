//
//  TriggerSessionManagerLogicTests.swift
//  
//
//  Created by Yusuf Tör on 11/05/2022.
//
// swiftlint:disable all

import XCTest
import StoreKit
@testable import SuperwallKit

final class TriggerSessionManagerLogicTests: XCTestCase {
  // MARK: - Outcome
  func testTrigger_unknownEvent() {
    let eventData = EventData(
      name: "fakeevent",
      parameters: [:],
      createdAt: Date()
    )

    let outcome = TriggerSessionManagerLogic.outcome(
      presentationInfo: .implicitTrigger(eventData),
      presentingViewController: nil,
      paywall: nil,
      triggerResult: .eventNotFound
    )

    XCTAssertNil(outcome)
  }

  @MainActor
  func testTrigger_holdout_noPaywallResponse() {
    let experiment = Experiment(
      id: "1",
      groupId: "2",
      variant: .init(
        id: "3",
        type: .holdout,
        paywallId: nil
      )
    )
    let eventName = "MyTrigger"
    
    let eventData = EventData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )
    let dependencyContainer = DependencyContainer()
    let viewController = dependencyContainer.makeDebugViewController(withDatabaseId: nil)

    let outcome = TriggerSessionManagerLogic.outcome(
      presentationInfo: .explicitTrigger(eventData),
      presentingViewController: viewController,
      paywall: nil,
      triggerResult: .holdout(experiment)
    )

    XCTAssertEqual(outcome?.presentationOutcome, .holdout)

    XCTAssertEqual(outcome?.trigger.eventId, eventData.id)
    XCTAssertEqual(outcome?.trigger.eventName, eventData.name)
    XCTAssertEqual(outcome?.trigger.eventParameters, eventData.parameters)
    XCTAssertEqual(outcome?.trigger.eventCreatedAt, eventData.createdAt)
    XCTAssertEqual(outcome?.trigger.type, .explicit)
    XCTAssertNil(outcome?.trigger.presentedOn)
    XCTAssertEqual(outcome?.trigger.experiment, experiment)
    XCTAssertNil(outcome?.paywall)
  }

  // Only need to test this paywall response once.
  func testPaywallResponse() {
    let experiment = Experiment(
      id: "1",
      groupId: "2",
      variant: .init(
        id: "3",
        type: .holdout,
        paywallId: nil
      )
    )
    let time = Date()
    let eventName = "MyTrigger"

    let eventData = EventData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )
    let paywallId = "abc"
    let paywallResponse: Paywall = .stub()
      .setting(\.databaseId, to: paywallId)
      .setting(\.responseLoadingInfo.startAt, to: time)
      .setting(\.responseLoadingInfo.endAt, to: time)
      .setting(\.webviewLoadingInfo.startAt, to: time)
      .setting(\.webviewLoadingInfo.endAt, to: time)

    let outcome = TriggerSessionManagerLogic.outcome(
      presentationInfo: .explicitTrigger(eventData),
      presentingViewController: nil,
      paywall: paywallResponse,
      triggerResult: .holdout(experiment)
    )

    XCTAssertEqual(outcome?.presentationOutcome, .holdout)

    XCTAssertEqual(outcome?.trigger.eventId, eventData.id)
    XCTAssertEqual(outcome?.trigger.eventName, eventData.name)
    XCTAssertEqual(outcome?.trigger.eventParameters, eventData.parameters)
    XCTAssertEqual(outcome?.trigger.eventCreatedAt, eventData.createdAt)
    XCTAssertEqual(outcome?.trigger.type, .explicit)
    XCTAssertNil(outcome?.trigger.presentedOn)
    XCTAssertEqual(outcome?.trigger.experiment, experiment)
    XCTAssertEqual(outcome?.paywall?.databaseId, paywallResponse.databaseId)
    let hasFreeTrial = outcome?.paywall?.substitutionPrefix == "freeTrial" ? true : false
    XCTAssertEqual(hasFreeTrial, paywallResponse.isFreeTrialAvailable)
    XCTAssertEqual(outcome?.paywall?.responseLoading.startAt, paywallResponse.responseLoadingInfo.startAt)
    XCTAssertEqual(outcome?.paywall?.responseLoading.endAt, paywallResponse.responseLoadingInfo.endAt)
    XCTAssertEqual(outcome?.paywall?.webviewLoading.startAt, paywallResponse.webviewLoadingInfo.startAt)
    XCTAssertEqual(outcome?.paywall?.webviewLoading.endAt, paywallResponse.webviewLoadingInfo.endAt)
  }

  func testTrigger_noRuleMatch_noPaywallResponse() {
    let eventName = "MyTrigger"
    let eventData = EventData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )

    let outcome = TriggerSessionManagerLogic.outcome(
      presentationInfo: .explicitTrigger(eventData),
      presentingViewController: nil,
      paywall: nil,
      triggerResult: .noRuleMatch
    )

    XCTAssertEqual(outcome?.presentationOutcome, .noRuleMatch)

    XCTAssertEqual(outcome?.trigger.eventId, eventData.id)
    XCTAssertEqual(outcome?.trigger.eventName, eventData.name)
    XCTAssertEqual(outcome?.trigger.eventParameters, eventData.parameters)
    XCTAssertEqual(outcome?.trigger.eventCreatedAt, eventData.createdAt)
    XCTAssertEqual(outcome?.trigger.type, .explicit)
    XCTAssertNil(outcome?.trigger.presentedOn)
    XCTAssertNil(outcome?.trigger.experiment)
    XCTAssertNil(outcome?.paywall)
  }

  @MainActor
  func testTrigger_Paywall_noPaywallResponse() {
    let experiment = Experiment(
      id: "1",
      groupId: "2",
      variant: .init(
        id: "3",
        type: .treatment,
        paywallId: nil
      )
    )
    let eventName = "MyTrigger"
    let eventData = EventData(
      name: eventName,
      parameters: [:],
      createdAt: Date()
    )

    let dependencyContainer = DependencyContainer()
    let viewController = dependencyContainer.makeDebugViewController(withDatabaseId: nil)

    let outcome = TriggerSessionManagerLogic.outcome(
      presentationInfo: .explicitTrigger(eventData),
      presentingViewController: viewController,
      paywall: nil,
      triggerResult: .paywall(experiment)
    )

    XCTAssertEqual(outcome?.presentationOutcome, .paywall)

    XCTAssertEqual(outcome?.trigger.eventId, eventData.id)
    XCTAssertEqual(outcome?.trigger.eventName, eventData.name)
    XCTAssertEqual(outcome?.trigger.eventParameters, eventData.parameters)
    XCTAssertEqual(outcome?.trigger.eventCreatedAt, eventData.createdAt)
    XCTAssertEqual(outcome?.trigger.type, .explicit)
    XCTAssertEqual(outcome?.trigger.presentedOn, "DebugViewController")
    XCTAssertEqual(outcome?.trigger.experiment, experiment)
    XCTAssertNil(outcome?.paywall)
  }

  @MainActor
  func testDefaultPaywall_noPaywallResponse() {
    let experiment = Experiment(
      id: "1",
      groupId: "2",
      variant: .init(
        id: "3",
        type: .treatment,
        paywallId: nil
      )
    )
    let eventName = "$present"
    let eventId = "eventId"
    let eventCreatedAt = Date()

    let event = EventData
      .stub()
      .setting(\.name, to: eventName)
      .setting(\.id, to: eventId)
      .setting(\.createdAt, to: eventCreatedAt)

    let dependencyContainer = DependencyContainer()
    let viewController = dependencyContainer.makeDebugViewController(withDatabaseId: nil)

    let presentationInfo = PresentationInfo.explicitTrigger(event)
    let outcome = TriggerSessionManagerLogic.outcome(
      presentationInfo: presentationInfo,
      presentingViewController: viewController,
      paywall: nil,
      triggerResult: .paywall(experiment)
    )

    XCTAssertEqual(outcome?.presentationOutcome, .paywall)

    XCTAssertEqual(outcome?.trigger.eventId, eventId)
    XCTAssertEqual(outcome?.trigger.eventName, eventName)
    XCTAssertEqual(outcome?.trigger.eventCreatedAt, eventCreatedAt)
    XCTAssertEqual(outcome?.trigger.type, .explicit)
    XCTAssertEqual(outcome?.trigger.presentedOn, "DebugViewController")
    XCTAssertEqual(outcome?.trigger.experiment, experiment)
    XCTAssertNil(outcome?.paywall)
  }

  @MainActor
  func testIdentifierPaywall_noPaywallResponse() {
    let eventName = "manual_present"

    let dependencyContainer = DependencyContainer()
    let viewController = dependencyContainer.makeDebugViewController(withDatabaseId: nil)

    let outcome = TriggerSessionManagerLogic.outcome(
      presentationInfo: .fromIdentifier("identifier", freeTrialOverride: false),
      presentingViewController: viewController,
      paywall: nil,
      triggerResult: nil
    )

    XCTAssertEqual(outcome?.presentationOutcome, .paywall)

    XCTAssertEqual(outcome?.trigger.eventName, eventName)
    XCTAssertEqual(outcome?.trigger.type, .explicit)
    XCTAssertEqual(outcome?.trigger.presentedOn, "DebugViewController")
    XCTAssertNil(outcome?.trigger.experiment)
    XCTAssertNil(outcome?.paywall)
  }

  // MARK: - getTransactionOutcome
  func testGetTransactionOutcome_withoutSubscriptionPeriod() {
    let product = MockSkProduct()

    let outcome = TriggerSessionManagerLogic.getTransactionOutcome(
      for: StoreProduct(sk1Product: product),
      isFreeTrialAvailable: false
    )

    XCTAssertEqual(outcome, .nonRecurringProductPurchase)
  }

  func testGetTransactionOutcome_hasFreeTrial() {
    let period = SKProductSubscriptionPeriodMock()
    let product = MockSkProduct(subscriptionPeriod: period)

    let outcome = TriggerSessionManagerLogic.getTransactionOutcome(
      for: StoreProduct(sk1Product: product),
      isFreeTrialAvailable: true
    )

    XCTAssertEqual(outcome, .trialStart)
  }

  func testGetTransactionOutcome_noFreeTrial() {
    let period = SKProductSubscriptionPeriodMock()
    let product = MockSkProduct(subscriptionPeriod: period)

    let outcome = TriggerSessionManagerLogic.getTransactionOutcome(
      for: StoreProduct(sk1Product: product),
      isFreeTrialAvailable: false
    )
    
    XCTAssertEqual(outcome, .subscriptionStart)
  }

  // MARK: - createPendingTriggerSession

  func testCreatePendingTriggerSession() {
    let requestId = "requestId"
    let userAttributes = ["name": "Bob"]
    let isSubscribed = false
    let eventName = "event name"
    let products = [SWProduct(product: MockSkProduct())]
    let appSession = AppSession()

    let session = TriggerSessionManagerLogic.createPendingTriggerSession(
      configRequestId: requestId,
      userAttributes: userAttributes,
      isSubscribed: isSubscribed,
      eventName: eventName,
      products: products,
      appSession: appSession
    )

    XCTAssertEqual(session.configRequestId, requestId)
    XCTAssertEqual(session.userAttributes?.first?.0, userAttributes.first?.0)
    XCTAssertEqual(session.isSubscribed, isSubscribed)
    XCTAssertEqual(session.trigger.eventName, eventName)
    XCTAssertEqual(session.products.allProducts.first?.productIdentifier, products.first?.productIdentifier)
    XCTAssertEqual(session.appSession.id, appSession.id)

    XCTAssertNil(session.trigger.experiment)
    XCTAssertNil(session.trigger.eventCreatedAt)
    XCTAssertNil(session.trigger.eventParameters)
    XCTAssertNil(session.trigger.eventId)
    XCTAssertNil(session.trigger.presentedOn)
    XCTAssertNil(session.trigger.type)
    XCTAssertNil(session.paywall)
    XCTAssertNil(session.endAt)
    XCTAssertNil(session.transaction)
  }
}
