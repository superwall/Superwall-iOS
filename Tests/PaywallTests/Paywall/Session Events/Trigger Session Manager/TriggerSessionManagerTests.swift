//
//  TriggerSessionManagerTests.swift
//  
//
//  Created by Yusuf Tör on 18/05/2022.
//
// swiftlint:disable all

import XCTest
@testable import Paywall

final class TriggerSessionManagerTests: XCTestCase {
  var queue: SessionEventsQueueMock!
  var sessionManager: TriggerSessionManager!
  var sessionEventsDelegate: SessionEventsDelegateMock!

  override func setUp() {
    queue = SessionEventsQueueMock()
    sessionEventsDelegate = SessionEventsDelegateMock(queue: queue)
    sessionManager = TriggerSessionManager(delegate: sessionEventsDelegate)
  }

  // MARK: - Create Config

  func testCreatePendingSessionsFromConfig() {
    let eventName = "MyTrigger"
    let config = createConfig(forEventName: eventName)

    // When
    sessionManager.createSessions(from: config)

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    let names = queue.triggerSessions.map { $0.trigger.eventName }
    XCTAssertTrue(names.contains(eventName))
  }

  private func createConfig(forEventName eventName: String) -> Config {
    // Given
    let rawExperiment = RawExperiment(
      id: "1",
      groupId: "2",
      variants: [.init(
        type: .holdout,
        id: "3",
        percentage: 100,
        paywallId: nil
      )]
    )
    let rule: TriggerRule = .stub()
      .setting(\.experiment, to: rawExperiment)
    let trigger = Trigger(
      eventName: eventName,
      rules: [rule]
    )
    let config: Config = .stub()
      .setting(\.triggers, to: [trigger])
    return config
  }

  // MARK: - Activate Pending Session

  func testActivatePendingSession_byIdentifier() {
    // Given
    let eventName = "MyTrigger"
    let config = createConfig(forEventName: eventName)
    sessionManager.createSessions(from: config)
    
    // When
    sessionManager.activateSession(
      for: .fromIdentifier("123"),
      triggerResult: nil
    )

    XCTAssertNil(queue.triggerSessions.last!.presentationOutcome)
  }

  func testActivatePendingSession_triggerNotFound() {
    // Given
    let eventName = "MyTrigger"

    let config = createConfig(forEventName: eventName)
    sessionManager.createSessions(from: config)

    let eventData: EventData = .stub()
      .setting(\.name, to: "AnotherTrigger")

    // When
    sessionManager.activateSession(
      for: .explicitTrigger(eventData),
      triggerResult: .triggerNotFound
    )

    XCTAssertNil(queue.triggerSessions.last!.presentationOutcome)
  }

  func testActivatePendingSession() {
    // Given
    let eventName = "MyTrigger"

    let config = createConfig(forEventName: eventName)
    sessionManager.createSessions(from: config)

    let eventData: EventData = .stub()
      .setting(\.name, to: eventName)
    let triggers = createTriggers(
      withName: eventName,
      variantType: .treatment
    )
    let rawExperiment = triggers[eventName]!.rules.first!.experiment
    let experiment = Experiment(
      id: rawExperiment.id,
      groupId: rawExperiment.groupId,
      variant: rawExperiment.variants.first!.toVariant()
    )

    // When
    sessionManager.activateSession(
      for: .explicitTrigger(eventData),
      triggerResult: .paywall(experiment: experiment)
    )

    XCTAssertEqual(queue.triggerSessions.count, 2)
    XCTAssertNil(queue.triggerSessions.last!.endAt)
    XCTAssertEqual(queue.triggerSessions.last!.presentationOutcome, .paywall)
  }

  func testActivatePendingSession_holdout() {
    // Given
    let eventName = "MyTrigger"
    let config = createConfig(forEventName: eventName)
    sessionManager.createSessions(from: config)

    let triggers = createTriggers(
      withName: eventName,
      variantType: .holdout
    )
    let rawExperiment = triggers[eventName]!.rules.first!.experiment
    let experiment = Experiment(
      id: rawExperiment.id,
      groupId: rawExperiment.groupId,
      variant: rawExperiment.variants.first!.toVariant()
    )
    let eventData: EventData = .stub()
      .setting(\.name, to: eventName)

    // When
    sessionManager.activateSession(
      for: .explicitTrigger(eventData),
      triggerResult: .holdout(experiment: experiment)
    )
    
    XCTAssertEqual(queue.triggerSessions.count, 2)
    XCTAssertNotNil(queue.triggerSessions.last!.endAt)
    XCTAssertEqual(queue.triggerSessions.last!.presentationOutcome, .holdout)
  }

  func testActivatePendingSession_noRuleMatch() {
    // Given
    let eventName = "MyTrigger"
    let config = createConfig(forEventName: eventName)
    sessionManager.createSessions(from: config)
    let eventData: EventData = .stub()
      .setting(\.name, to: eventName)

    // When
    sessionManager.activateSession(
      for: .explicitTrigger(eventData),
      triggerResult: .noRuleMatch
    )

    XCTAssertEqual(queue.triggerSessions.count, 2)
    XCTAssertNotNil(queue.triggerSessions.last!.endAt)
    XCTAssertEqual(queue.triggerSessions.last!.presentationOutcome, .noRuleMatch)
  }

  private func createTriggers(
    withName eventName: String,
    variantType: Experiment.Variant.VariantType
  ) -> [String: Trigger] {
    let rawExperiment = RawExperiment(
      id: "1",
      groupId: "2",
      variants: [.init(
        type: variantType,
        id: "3",
        percentage: 100,
        paywallId: variantType == .treatment ? "123" : nil
      )]
    )
    let rule: TriggerRule = .stub()
      .setting(\.experiment, to: rawExperiment)
    let trigger = Trigger(
      eventName: eventName,
      rules: [rule]
    )

    return [eventName: trigger]
  }

  // MARK: - Ending Session
  func testEndSession_noActiveSession() {
    // Given
    let eventName = "MyTrigger"
    let config = createConfig(forEventName: eventName)
    sessionManager.createSessions(from: config)


    // When
    sessionManager.endSession()

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNil(queue.triggerSessions[0].endAt)
  }

  func testEndSession() {
    // Given
    let eventName = "MyTrigger"
    let config = createConfig(forEventName: eventName)
    sessionManager.createSessions(from: config)

    let eventData: EventData = .stub()
      .setting(\.name, to: eventName)
    let triggers = createTriggers(
      withName: eventName,
      variantType: .treatment
    )
    let rawExperiment = triggers[eventName]!.rules.first!.experiment
    let experiment = Experiment(
      id: rawExperiment.id,
      groupId: rawExperiment.groupId,
      variant: rawExperiment.variants.first!.toVariant()
    )
    sessionManager.activateSession(
      for: .explicitTrigger(eventData),
      triggerResult: .paywall(experiment: experiment)
    )

    // When
    sessionManager.endSession()

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 3)
    XCTAssertNil(queue.triggerSessions[0].endAt)
    XCTAssertNil(queue.triggerSessions[1].endAt)
    XCTAssertNotNil(queue.triggerSessions[2].endAt)
  }

  // MARK: - Update App Session
  func testUpdateAppSession() {
    let appSession: AppSession = AppSession()

    let paywallId = "abc"
    activateSession(withPaywallId: paywallId)

    XCTAssertEqual(queue.triggerSessions.count, 2)
    XCTAssertNotEqual(queue.triggerSessions[0].appSession, appSession)

    queue.triggerSessions.removeAll()

    // When
    sessionManager.updateAppSession(to: appSession)

    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertEqual(queue.triggerSessions[0].appSession, appSession)
  }

  // MARK: - Paywall
  func testPaywallOpen() {
    // Given
    activateSession()

    XCTAssertNil(queue.triggerSessions.last!.paywall?.action.openAt)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackPaywallOpen()

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.first!.paywall?.action.openAt)
  }

  func testPaywallClose() {
    // Given
    activateSession()

    XCTAssertNil(queue.triggerSessions.last!.paywall?.action.closeAt)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackPaywallClose()

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.first!.paywall?.action.closeAt)
  }

  private func activateSession(
    withPaywallId paywallId: String = "123",
    products: [SWProduct] = [SWProduct(product: MockSkProduct())]
  ) {
    let eventName = "MyTrigger"
    let config = createConfig(forEventName: eventName)
    sessionManager.createSessions(from: config)

    let eventData: EventData = .stub()
      .setting(\.name, to: eventName)
    let triggers = createTriggers(
      withName: eventName,
      variantType: .treatment
    )
    let experiment = triggers[eventName]!.rules.first!.experiment
    let paywallResponse: PaywallResponse = .stub()
      .setting(\.id, to: paywallId)
      .setting(\.swProducts, to: products)
    sessionManager.activateSession(
      for: .explicitTrigger(eventData),
      paywallResponse: paywallResponse,
      triggerResult: .paywall(experiment: Experiment(
         id: experiment.id,
        groupId: experiment.groupId,
        variant: experiment.variants.first!.toVariant()
      )
    ))
  }

  // MARK: - Webview Load
  func testWebviewLoad_start() {
    // Given
    let paywallId = "abc"
    activateSession(withPaywallId: paywallId)

    XCTAssertNil(queue.triggerSessions.last!.paywall?.webviewLoading.startAt)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackWebviewLoad(
      forPaywallId: paywallId,
      state: .start
    )

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.paywall?.webviewLoading.startAt)
  }

  func testWebviewLoad_end() {
    // Given
    let paywallId = "abc"
    activateSession(withPaywallId: paywallId)

    XCTAssertNil(queue.triggerSessions.last!.paywall?.webviewLoading.endAt)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackWebviewLoad(
      forPaywallId: paywallId,
      state: .end
    )

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.paywall?.webviewLoading.endAt)
  }

  func testWebviewLoad_fail() {
    // Given
    let paywallId = "abc"
    activateSession(withPaywallId: paywallId)

    XCTAssertNil(queue.triggerSessions.last!.paywall?.webviewLoading.failAt)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackWebviewLoad(
      forPaywallId: paywallId,
      state: .fail
    )

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.paywall?.webviewLoading.failAt)
  }

  // MARK: - Paywall Response Load

  func testPaywallResponseLoad_start() {
    // Given
    let paywallId = "abc"
    activateSession(withPaywallId: paywallId)

    XCTAssertNil(queue.triggerSessions.last!.paywall?.responseLoading.startAt)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackPaywallResponseLoad(
      forPaywallId: paywallId,
      state: .start
    )

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.paywall?.responseLoading.startAt)
  }

  func testPaywallResponseLoad_end() {
    // Given
    let paywallId = "abc"
    activateSession(withPaywallId: paywallId)

    XCTAssertNil(queue.triggerSessions.last!.paywall?.responseLoading.endAt)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackPaywallResponseLoad(
      forPaywallId: paywallId,
      state: .end
    )

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.paywall?.responseLoading.endAt)
  }

  func testPaywallResponseLoad_fail() {
    // Given
    let paywallId = "abc"
    activateSession(withPaywallId: paywallId)

    XCTAssertNil(queue.triggerSessions.last!.paywall?.responseLoading.failAt)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackPaywallResponseLoad(
      forPaywallId: paywallId,
      state: .fail
    )

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.paywall?.responseLoading.failAt)
  }

  // MARK: - Products

  func testProductsLoad_start() {
    // Given
    let paywallId = "abc"
    activateSession(withPaywallId: paywallId)

    XCTAssertNil(queue.triggerSessions.last!.products.loadingInfo?.startAt)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackProductsLoad(
      forPaywallId: paywallId,
      state: .start
    )

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.products.loadingInfo?.startAt)
  }

  func testProductsLoad_end() {
    // Given
    let paywallId = "abc"
    activateSession(withPaywallId: paywallId)

    XCTAssertNil(queue.triggerSessions.last!.products.loadingInfo?.endAt)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackProductsLoad(
      forPaywallId: paywallId,
      state: .end
    )

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.products.loadingInfo?.endAt)
  }

  func testProductsLoad_fail() {
    // Given
    let paywallId = "abc"
    activateSession(withPaywallId: paywallId)

    XCTAssertNil(queue.triggerSessions.last!.products.loadingInfo?.failAt)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackProductsLoad(
      forPaywallId: paywallId,
      state: .fail
    )

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.products.loadingInfo?.failAt)
  }

  // MARK: - Transactions

  func testBeginTransaction_firstTime() {
    // Given
    let primaryProduct = MockSkProduct(productIdentifier: "primary")
    beginTransactionOf(primaryProduct: primaryProduct)

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(start: 1)
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction?.startAt)
    XCTAssertNil(queue.triggerSessions.last!.transaction?.endAt)
    XCTAssertNil(queue.triggerSessions.last!.transaction?.status)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.count, expectedTransactionCount)
    XCTAssertNil(queue.triggerSessions.last!.transaction?.outcome)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.product, .init(from: primaryProduct, index: 0))
  }

  private func beginTransactionOf(primaryProduct product: MockSkProduct) {
    // Given
    let paywallId = "abc"
    let products = [
      SWProduct(product: product),
      SWProduct(product: MockSkProduct()),
      SWProduct(product: MockSkProduct())
    ]
    activateSession(
      withPaywallId: paywallId,
      products: products
    )

    XCTAssertNil(queue.triggerSessions.last!.transaction)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackBeginTransaction(of: product)
  }

  func testBeginTransaction_secondTime() {
    // Given
    let primaryProduct = MockSkProduct(productIdentifier: "primary")
    beginTransactionOf(primaryProduct: primaryProduct)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackBeginTransaction(of: primaryProduct)

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(start: 2)
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction?.startAt)
    XCTAssertNil(queue.triggerSessions.last!.transaction?.endAt)
    XCTAssertNil(queue.triggerSessions.last!.transaction?.status)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.count, expectedTransactionCount)
    XCTAssertNil(queue.triggerSessions.last!.transaction?.outcome)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.product, .init(from: primaryProduct, index: 0))
  }

  func testTransactionError() {
    // Given
    let primaryProduct = MockSkProduct(productIdentifier: "primary")
    beginTransactionOf(primaryProduct: primaryProduct)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackTransactionError()

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(start: 1, fail: 1)
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction?.startAt)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction?.endAt)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.status, .fail)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.count, expectedTransactionCount)
    XCTAssertNil(queue.triggerSessions.last!.transaction?.outcome)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.product, .init(from: primaryProduct, index: 0))
  }

  func testTransactionAbandon() {
    // Given
    let primaryProduct = MockSkProduct(productIdentifier: "primary")
    beginTransactionOf(primaryProduct: primaryProduct)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackTransactionAbandon()

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(start: 1, abandon: 1)
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction?.startAt)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction?.endAt)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.status, .abandon)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.count, expectedTransactionCount)
    XCTAssertNil(queue.triggerSessions.last!.transaction?.outcome)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.product, .init(from: primaryProduct, index: 0))
  }

  func testTransactionRestoration_noPreviousTransactionActions() {
    // Given
    let paywallId = "abc"
    let primaryProduct = MockSkProduct(productIdentifier: "primary")
    let products = [
      SWProduct(product: primaryProduct),
      SWProduct(product: MockSkProduct()),
      SWProduct(product: MockSkProduct())
    ]
    activateSession(
      withPaywallId: paywallId,
      products: products
    )

    XCTAssertNil(queue.triggerSessions.last!.transaction)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackTransactionRestoration(
      withId: "abc",
      product: primaryProduct,
      isFreeTrialAvailable: false
    )

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(restore: 1)
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertEqual(
      queue.triggerSessions.last!.transaction?.startAt,
      queue.triggerSessions.last!.transaction?.endAt
    )
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.status, .complete)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.count, expectedTransactionCount)
    XCTAssertNil(queue.triggerSessions.last!.transaction?.outcome)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.product, .init(from: primaryProduct, index: 0))
  }

  func testTransactionRestoration_withPreviousTransactionActions() {
    // Given
    let primaryProduct = MockSkProduct(productIdentifier: "primary")
    beginTransactionOf(primaryProduct: primaryProduct)
    let oldTransaction = queue.triggerSessions.last!.transaction
    XCTAssertNotNil(queue.triggerSessions.last!.transaction)

    sessionManager.trackTransactionAbandon()
    XCTAssertNotNil(queue.triggerSessions.last!.transaction)

    queue.triggerSessions.removeAll()


    // When
    sessionManager.trackTransactionRestoration(
      withId: "abc",
      product: primaryProduct,
      isFreeTrialAvailable: false
    )

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(start: 1, abandon: 1, restore: 1)
    XCTAssertNotEqual(queue.triggerSessions.last?.id, oldTransaction?.id)
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertEqual(
      queue.triggerSessions.last!.transaction?.startAt,
      queue.triggerSessions.last!.transaction?.endAt
    )
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.status, .complete)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.count, expectedTransactionCount)
    XCTAssertNil(queue.triggerSessions.last!.transaction?.outcome)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.product, .init(from: primaryProduct, index: 0))
  }

  func testTransactionDeferred() {
    // Given
    let primaryProduct = MockSkProduct(productIdentifier: "primary")
    beginTransactionOf(primaryProduct: primaryProduct)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackDeferredTransaction()

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(start: 1, fail: 1)
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction?.startAt)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction?.endAt)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.status, .fail)
    XCTAssertNil(queue.triggerSessions.last!.transaction?.outcome)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.count, expectedTransactionCount)
  }

  func testTransactionSucceeded() {
    // Given
    let id = "abc"
    let primaryProduct = MockSkProduct(productIdentifier: "primary")
    beginTransactionOf(primaryProduct: primaryProduct)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction)
    queue.triggerSessions.removeAll()

    // When
    sessionManager.trackTransactionSucceeded(
      withId: id,
      for: primaryProduct,
      isFreeTrialAvailable: true
    )

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(start: 1, complete: 1)
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction?.id, id)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction?.startAt)
    XCTAssertNotNil(queue.triggerSessions.last!.transaction?.endAt)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.status, .complete)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.outcome, .nonRecurringProductPurchase)
    XCTAssertNotNil(queue.triggerSessions.last!.paywall?.action.convertedAt)
    XCTAssertEqual(queue.triggerSessions.last!.transaction?.count, expectedTransactionCount)
  }

  // MARK: - App Lifecycle

  func testAppDidEnterBackground() {
    // Given
    let paywallId = "abc"
    activateSession(withPaywallId: paywallId)
    let lastTriggerSession = queue.triggerSessions.last!
    XCTAssertNil(lastTriggerSession.endAt)
    queue.triggerSessions.removeAll()

    // When
    NotificationCenter.default.post(Notification(name: UIApplication.didEnterBackgroundNotification))

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertEqual(queue.triggerSessions.last?.id, lastTriggerSession.id)
    XCTAssertNotNil(queue.triggerSessions.last!.endAt)
  }

  func testAppDidEnterForeground() {
    // Given
    let paywallId = "abc"
    activateSession(withPaywallId: paywallId)
    let lastTriggerSession = queue.triggerSessions.last!
    NotificationCenter.default.post(Notification(name: UIApplication.didEnterBackgroundNotification))
    queue.triggerSessions.removeAll()

    // When
    NotificationCenter.default.post(Notification(name: UIApplication.willEnterForegroundNotification))

    // Then
    XCTAssertEqual(queue.triggerSessions.count, 1)
    XCTAssertNotEqual(queue.triggerSessions.last?.id, lastTriggerSession.id)
    XCTAssertNil(queue.triggerSessions.last!.endAt)
  }
}
