//
//  TriggerSessionManagerTests.swift
//  
//
//  Created by Yusuf Tör on 18/05/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

final class TriggerSessionManagerTests: XCTestCase {
  var queue: SessionEnqueuable!
  var sessionManager: TriggerSessionManager!
  var sessionEventsDelegate: SessionEventsDelegateMock!

  override func setUp() {
    queue = MockSessionEventsQueue()
    sessionEventsDelegate = SessionEventsDelegateMock(queue: queue)
    let dependencyContainer = DependencyContainer(apiKey: "")
    
    sessionManager = TriggerSessionManager(
      delegate: sessionEventsDelegate,
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      storage: dependencyContainer.storage,
      configManager: dependencyContainer.configManager,
      appSessionManager: dependencyContainer.appSessionManager,
      identityManager: dependencyContainer.identityManager
    )
    sessionEventsDelegate.triggerSession = sessionManager
  }

  // MARK: - Create Config

  func testCreatePendingSessionsFromConfig() async {
    let eventName = "MyTrigger"
    let config = createConfig(forEventName: eventName)

    // When
    await sessionManager.createSessions(from: config)

    // Then
    let triggerSessionCount = await queue.triggerSessions.count
    XCTAssertEqual(triggerSessionCount, 1)
    let names = await queue.triggerSessions.map { $0.trigger.eventName }
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

  func testActivatePendingSession_byIdentifier() async {
    // Given
    let eventName = "MyTrigger"
    let config = createConfig(forEventName: eventName)
    await sessionManager.createSessions(from: config)
    
    // When
    await sessionManager.activateSession(
      for: .fromIdentifier("123", freeTrialOverride: false),
      triggerResult: nil
    )

    let triggerSession = await queue.triggerSessions.last
    XCTAssertNil(triggerSession?.presentationOutcome)
  }

  func testActivatePendingSession_triggerNotFound() async {
    // Given
    let eventName = "MyTrigger"

    let config = createConfig(forEventName: eventName)
    await sessionManager.createSessions(from: config)

    let eventData: EventData = .stub()
      .setting(\.name, to: "AnotherTrigger")

    // When
    await sessionManager.activateSession(
      for: .explicitTrigger(eventData),
      triggerResult: .eventNotFound
    )

    let presentationOutcome = await queue.triggerSessions.last!.presentationOutcome
    XCTAssertNil(presentationOutcome)
  }

  func testActivatePendingSession() async {
    // Given
    let eventName = "MyTrigger"

    let config = createConfig(forEventName: eventName)
    await sessionManager.createSessions(from: config)

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
    await sessionManager.activateSession(
      for: .explicitTrigger(eventData),
      triggerResult: .paywall(experiment)
    )


    let triggerSessions = await queue.triggerSessions
    XCTAssertEqual(triggerSessions.count, 2)
    XCTAssertNil(triggerSessions.last!.endAt)
    XCTAssertEqual(triggerSessions.last!.presentationOutcome, .paywall)
  }

  func testActivatePendingSession_holdout() async {
    // Given
    let eventName = "MyTrigger"
    let config = createConfig(forEventName: eventName)
    await sessionManager.createSessions(from: config)

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
    await sessionManager.activateSession(
      for: .explicitTrigger(eventData),
      triggerResult: .holdout(experiment)
    )

    let triggerSessions = await queue.triggerSessions
    XCTAssertEqual(triggerSessions.count, 2)
    XCTAssertNotNil(triggerSessions.last!.endAt)
    XCTAssertEqual(triggerSessions.last!.presentationOutcome, .holdout)
  }

  func testActivatePendingSession_noRuleMatch() async {
    // Given
    let eventName = "MyTrigger"
    let config = createConfig(forEventName: eventName)
    await sessionManager.createSessions(from: config)
    let eventData: EventData = .stub()
      .setting(\.name, to: eventName)

    // When
    await sessionManager.activateSession(
      for: .explicitTrigger(eventData),
      triggerResult: .noRuleMatch
    )

    let triggerSessions = await queue.triggerSessions
    XCTAssertEqual(triggerSessions.count, 2)
    XCTAssertNotNil(triggerSessions.last!.endAt)
    XCTAssertEqual(triggerSessions.last!.presentationOutcome, .noRuleMatch)
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
  func testEndSession_noActiveSession() async {
    // Given
    let eventName = "MyTrigger"
    let config = createConfig(forEventName: eventName)
    await sessionManager.createSessions(from: config)


    // When
    await sessionManager.endSession()

    // Then
    let triggerSessions = await queue.triggerSessions
    XCTAssertEqual(triggerSessions.count, 1)
    XCTAssertNil(triggerSessions[0].endAt)
  }

  func testEndSession() async {
    // Given
    let eventName = "MyTrigger"
    let config = createConfig(forEventName: eventName)
    await sessionManager.createSessions(from: config)

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
    await sessionManager.activateSession(
      for: .explicitTrigger(eventData),
      triggerResult: .paywall(experiment)
    )

    // When
    await sessionManager.endSession()

    // Then
    let triggerSessions = await queue.triggerSessions
    XCTAssertEqual(triggerSessions.count, 3)
    XCTAssertNil(triggerSessions[0].endAt)
    XCTAssertNil(triggerSessions[1].endAt)
    XCTAssertNotNil(triggerSessions[2].endAt)
  }

  // MARK: - Update App Session
  func testUpdateAppSession() async {
    let appSession: AppSession = AppSession()

    let paywallId = "abc"
    await activateSession(withPaywallId: paywallId)

    let triggerSessions = await queue.triggerSessions
    XCTAssertEqual(triggerSessions.count, 2)
    XCTAssertNotEqual(triggerSessions[0].appSession, appSession)

    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.updateAppSession(to: appSession)

    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertEqual(triggerSessions2[0].appSession, appSession)
  }

  // MARK: - Paywall
  func testPaywallOpen() async {
    // Given
    await activateSession()

    let triggerSessions = await queue.triggerSessions
    XCTAssertNil(triggerSessions.last!.paywall?.action.openAt)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackPaywallOpen()

    // Then

    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.first!.paywall?.action.openAt)
  }

  func testPaywallClose() async {
    // Given
    await activateSession()

    let triggerSessions = await queue.triggerSessions
    XCTAssertNil(triggerSessions.last!.paywall?.action.closeAt)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackPaywallClose()

    // Then
    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.first!.paywall?.action.closeAt)
  }

  private func activateSession(
    withPaywallId paywallId: String = "123",
    products: [SWProduct] = [SWProduct(product: MockSkProduct())]
  ) async {
    let eventName = "MyTrigger"
    let config = createConfig(forEventName: eventName)
    await sessionManager.createSessions(from: config)

    let eventData: EventData = .stub()
      .setting(\.name, to: eventName)
    let triggers = createTriggers(
      withName: eventName,
      variantType: .treatment
    )
    let experiment = triggers[eventName]!.rules.first!.experiment
    let paywallResponse: Paywall = .stub()
      .setting(\.databaseId, to: paywallId)
      .setting(\.swProducts, to: products)
    await sessionManager.activateSession(
      for: .explicitTrigger(eventData),
      paywall: paywallResponse,
      triggerResult: .paywall(
        Experiment(
         id: experiment.id,
        groupId: experiment.groupId,
        variant: experiment.variants.first!.toVariant()
      )
    ))
  }

  // MARK: - Webview Load
  func testWebviewLoad_start() async {
    // Given
    let paywallId = "abc"
    await activateSession(withPaywallId: paywallId)

    let triggerSessions = await queue.triggerSessions
    XCTAssertNil(triggerSessions.last!.paywall?.webviewLoading.startAt)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackWebviewLoad(
      forPaywallId: paywallId,
      state: .start
    )

    // Then
    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.last!.paywall?.webviewLoading.startAt)
  }

  func testWebviewLoad_end() async {
    // Given
    let paywallId = "abc"
    await activateSession(withPaywallId: paywallId)

    let triggerSessions = await queue.triggerSessions
    XCTAssertNil(triggerSessions.last!.paywall?.webviewLoading.endAt)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackWebviewLoad(
      forPaywallId: paywallId,
      state: .end
    )

    // Then
    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.last!.paywall?.webviewLoading.endAt)
  }

  func testWebviewLoad_fail() async {
    // Given
    let paywallId = "abc"
    await activateSession(withPaywallId: paywallId)

    let triggerSessions = await queue.triggerSessions
    XCTAssertNil(triggerSessions.last!.paywall?.webviewLoading.failAt)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackWebviewLoad(
      forPaywallId: paywallId,
      state: .fail
    )

    // Then
    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.last!.paywall?.webviewLoading.failAt)
  }

  // MARK: - Paywall Response Load

  func testPaywallResponseLoad_start() async {
    // Given
    let paywallId = "abc"
    await activateSession(withPaywallId: paywallId)

    let triggerSessions = await queue.triggerSessions
    XCTAssertNil(triggerSessions.last!.paywall?.responseLoading.startAt)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackPaywallResponseLoad(
      forPaywallId: paywallId,
      state: .start
    )

    // Then

    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.last!.paywall?.responseLoading.startAt)
  }

  func testPaywallResponseLoad_end() async {
    // Given
    let paywallId = "abc"
    await activateSession(withPaywallId: paywallId)

    let triggerSessions = await queue.triggerSessions
    XCTAssertNil(triggerSessions.last!.paywall?.responseLoading.endAt)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackPaywallResponseLoad(
      forPaywallId: paywallId,
      state: .end
    )

    // Then
    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.last!.paywall?.responseLoading.endAt)
  }

  func testPaywallResponseLoad_fail() async {
    // Given
    let paywallId = "abc"
    await activateSession(withPaywallId: paywallId)

    let triggerSessions = await queue.triggerSessions
    XCTAssertNil(triggerSessions.last!.paywall?.responseLoading.failAt)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackPaywallResponseLoad(
      forPaywallId: paywallId,
      state: .fail
    )

    // Then
    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.last!.paywall?.responseLoading.failAt)
  }

  // MARK: - Products

  func testProductsLoad_start() async {
    // Given
    let paywallId = "abc"
    await activateSession(withPaywallId: paywallId)

    let triggerSessions = await queue.triggerSessions
    XCTAssertNil(triggerSessions.last!.products.loadingInfo?.startAt)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackProductsLoad(
      forPaywallId: paywallId,
      state: .start
    )

    // Then

    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.last!.products.loadingInfo?.startAt)
  }

  func testProductsLoad_end() async {
    // Given
    let paywallId = "abc"
    await activateSession(withPaywallId: paywallId)

    let triggerSessions = await queue.triggerSessions
    XCTAssertNil(triggerSessions.last!.products.loadingInfo?.endAt)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackProductsLoad(
      forPaywallId: paywallId,
      state: .end
    )

    // Then
    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.last!.products.loadingInfo?.endAt)
  }

  func testProductsLoad_fail() async {
    // Given
    let paywallId = "abc"
    await activateSession(withPaywallId: paywallId)

    let triggerSessions = await queue.triggerSessions
    XCTAssertNil(triggerSessions.last!.products.loadingInfo?.failAt)
    await queue.removeAllTriggerSessions()

    let triggerSessions21 = await queue.triggerSessions
    print("Anything?", triggerSessions21)

    // When
    await sessionManager.trackProductsLoad(
      forPaywallId: paywallId,
      state: .fail
    )

    // Then
    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.last!.products.loadingInfo?.failAt)
  }

  // MARK: - Transactions

  func testBeginTransaction_firstTime() async {
    // Given
    let primaryProduct = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "primary"))
    await beginTransactionOf(primaryProduct: primaryProduct)

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(start: 1)

    let triggerSessions = await queue.triggerSessions
    XCTAssertEqual(triggerSessions.count, 1)
    XCTAssertNotNil(triggerSessions.last!.transaction?.startAt)
    XCTAssertNil(triggerSessions.last!.transaction?.endAt)
    XCTAssertNil(triggerSessions.last!.transaction?.status)
    XCTAssertEqual(triggerSessions.last!.transaction?.count, expectedTransactionCount)
    XCTAssertNil(triggerSessions.last!.transaction?.outcome)
    XCTAssertEqual(triggerSessions.last!.transaction?.product, .init(from: primaryProduct, index: 0))
  }

  private func beginTransactionOf(primaryProduct product: StoreProduct) async {
    // Given
    let paywallId = "abc"
    let products = [
      SWProduct(product: product.underlyingSK1Product),
      SWProduct(product: MockSkProduct()),
      SWProduct(product: MockSkProduct())
    ]
    await activateSession(
      withPaywallId: paywallId,
      products: products
    )

    let triggerSessions = await queue.triggerSessions
    XCTAssertNil(triggerSessions.last!.transaction)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackBeginTransaction(of: product)
  }

  func testBeginTransaction_secondTime() async  {
    // Given
    let primaryProduct = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "primary"))
    await beginTransactionOf(primaryProduct: primaryProduct)

    let triggerSessions = await queue.triggerSessions
    XCTAssertNotNil(triggerSessions.last!.transaction)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackBeginTransaction(of: primaryProduct)

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(start: 2)

    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.last!.transaction?.startAt)
    XCTAssertNil(triggerSessions2.last!.transaction?.endAt)
    XCTAssertNil(triggerSessions2.last!.transaction?.status)
    XCTAssertEqual(triggerSessions2.last!.transaction?.count, expectedTransactionCount)
    XCTAssertNil(triggerSessions2.last!.transaction?.outcome)
    XCTAssertEqual(triggerSessions2.last!.transaction?.product, .init(from: primaryProduct, index: 0))
  }

  func testTransactionError() async {
    // Given
    let primaryProduct = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "primary"))
    await beginTransactionOf(primaryProduct: primaryProduct)
    let triggerSessions = await queue.triggerSessions
    XCTAssertNotNil(triggerSessions.last!.transaction)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackTransactionError()

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(start: 1, fail: 1)

    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.last!.transaction?.startAt)
    XCTAssertNotNil(triggerSessions2.last!.transaction?.endAt)
    XCTAssertEqual(triggerSessions2.last!.transaction?.status, .fail)
    XCTAssertEqual(triggerSessions2.last!.transaction?.count, expectedTransactionCount)
    XCTAssertNil(triggerSessions2.last!.transaction?.outcome)
    XCTAssertEqual(triggerSessions2.last!.transaction?.product, .init(from: primaryProduct, index: 0))
  }

  func testTransactionAbandon() async {
    // Given
    let primaryProduct = StoreProduct(sk1Product: MockSkProduct(productIdentifier: "primary"))
    await beginTransactionOf(primaryProduct: primaryProduct)
    let triggerSessions = await queue.triggerSessions
    XCTAssertNotNil(triggerSessions.last!.transaction)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackTransactionAbandon()

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(start: 1, abandon: 1)
    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.last!.transaction?.startAt)
    XCTAssertNotNil(triggerSessions2.last!.transaction?.endAt)
    XCTAssertEqual(triggerSessions2.last!.transaction?.status, .abandon)
    XCTAssertEqual(triggerSessions2.last!.transaction?.count, expectedTransactionCount)
    XCTAssertNil(triggerSessions2.last!.transaction?.outcome)
    XCTAssertEqual(triggerSessions2.last!.transaction?.product, .init(from: primaryProduct, index: 0))
  }

  func testTransactionRestoration_noPreviousTransactionActions() async {
    // Given
    let paywallId = "abc"
    let primaryProduct =  StoreProduct(sk1Product: MockSkProduct(productIdentifier: "primary"))
    let products = [
      SWProduct(product: primaryProduct.underlyingSK1Product),
      SWProduct(product: MockSkProduct()),
      SWProduct(product: MockSkProduct())
    ]
    await activateSession(
      withPaywallId: paywallId,
      products: products
    )

    let triggerSessions = await queue.triggerSessions
    XCTAssertNil(triggerSessions.last!.transaction)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackTransactionRestoration(
      withId: "abc",
      product: primaryProduct
    )

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(restore: 1)

    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertEqual(
      triggerSessions2.last!.transaction?.startAt,
      triggerSessions2.last!.transaction?.endAt
    )
    XCTAssertEqual(triggerSessions2.last!.transaction?.status, .complete)
    XCTAssertEqual(triggerSessions2.last!.transaction?.count, expectedTransactionCount)
    XCTAssertNil(triggerSessions2.last!.transaction?.outcome)
    XCTAssertEqual(triggerSessions2.last!.transaction?.product, .init(from: primaryProduct, index: 0))
  }

  func testTransactionRestoration_withPreviousTransactionActions() async {
    // Given
    let primaryProduct =  StoreProduct(sk1Product: MockSkProduct(productIdentifier: "primary"))
    await beginTransactionOf(primaryProduct: primaryProduct)

    let triggerSessions = await queue.triggerSessions
    let oldTransaction = triggerSessions.last!.transaction
    XCTAssertNotNil(triggerSessions.last!.transaction)

    await sessionManager.trackTransactionAbandon()

    let triggerSessions2 = await queue.triggerSessions
    XCTAssertNotNil(triggerSessions2.last!.transaction)

    await queue.removeAllTriggerSessions()


    // When
    await sessionManager.trackTransactionRestoration(
      withId: "abc",
      product: primaryProduct
    )

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(start: 1, abandon: 1, restore: 1)

    let triggerSessions3 = await queue.triggerSessions
    XCTAssertNotEqual(triggerSessions3.last?.id, oldTransaction?.id)
    XCTAssertEqual(triggerSessions3.count, 1)
    XCTAssertEqual(
      triggerSessions3.last!.transaction?.startAt,
      triggerSessions3.last!.transaction?.endAt
    )
    XCTAssertEqual(triggerSessions3.last!.transaction?.status, .complete)
    XCTAssertEqual(triggerSessions3.last!.transaction?.count, expectedTransactionCount)
    XCTAssertNil(triggerSessions3.last!.transaction?.outcome)
    XCTAssertEqual(triggerSessions3.last!.transaction?.product, .init(from: primaryProduct, index: 0))
  }

  func testTransactionDeferred() async {
    // Given
    let primaryProduct =  StoreProduct(sk1Product: MockSkProduct(productIdentifier: "primary"))
    await beginTransactionOf(primaryProduct: primaryProduct)

    let triggerSessions = await queue.triggerSessions
    XCTAssertNotNil(triggerSessions.last!.transaction)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackPendingTransaction()

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(start: 1, fail: 1)

    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.last!.transaction?.startAt)
    XCTAssertNotNil(triggerSessions2.last!.transaction?.endAt)
    XCTAssertEqual(triggerSessions2.last!.transaction?.status, .fail)
    XCTAssertNil(triggerSessions2.last!.transaction?.outcome)
    XCTAssertEqual(triggerSessions2.last!.transaction?.count, expectedTransactionCount)
  }

  func testTransactionSucceeded() async {
    // Given
    let id = "abc"
    let primaryProduct =  StoreProduct(sk1Product: MockSkProduct(productIdentifier: "primary"))
    await beginTransactionOf(primaryProduct: primaryProduct)

    let triggerSessions = await queue.triggerSessions
    XCTAssertNotNil(triggerSessions.last!.transaction)
    await queue.removeAllTriggerSessions()

    // When
    await sessionManager.trackTransactionSucceeded(
      withId: id,
      for: primaryProduct,
      isFreeTrialAvailable: false
    )

    // Then
    let expectedTransactionCount = TriggerSession.Transaction.Count(start: 1, complete: 1)

    let triggerSessions2 = await queue.triggerSessions
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotNil(triggerSessions2.last!.transaction?.id, id)
    XCTAssertNotNil(triggerSessions2.last!.transaction?.startAt)
    XCTAssertNotNil(triggerSessions2.last!.transaction?.endAt)
    XCTAssertEqual(triggerSessions2.last!.transaction?.status, .complete)
    XCTAssertEqual(triggerSessions2.last!.transaction?.outcome, .nonRecurringProductPurchase)
    XCTAssertNotNil(triggerSessions2.last!.paywall?.action.convertedAt)
    XCTAssertEqual(triggerSessions2.last!.transaction?.count, expectedTransactionCount)
  }

  // MARK: - App Lifecycle

  func testAppDidEnterBackground() async {
    // Given
    let paywallId = "abc"
    await activateSession(withPaywallId: paywallId)
    let triggerSessions = await queue.triggerSessions
    let lastTriggerSession = triggerSessions.last!
    XCTAssertNil(lastTriggerSession.endAt)
    await queue.removeAllTriggerSessions()

    // When
    await NotificationCenter.default.post(Notification(name: UIApplication.didEnterBackgroundNotification))

    // Then
    try? await Task.sleep(nanoseconds: 100_000_000)

    let triggerSessions2 = await queue.triggerSessions
    
    try? await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertEqual(triggerSessions2.last?.id, lastTriggerSession.id)
    XCTAssertNotNil(triggerSessions2.last!.endAt)
  }

  func testAppDidEnterForeground() async {
    // Given
    let paywallId = "abc"
    await activateSession(withPaywallId: paywallId)
    let lastTriggerSession = await queue.triggerSessions.last!
    await NotificationCenter.default.post(Notification(name: UIApplication.didEnterBackgroundNotification))

    try? await Task.sleep(nanoseconds: 100_000_000)

    await queue.removeAllTriggerSessions()

    let triggerSessions1 = await queue.triggerSessions
    XCTAssertTrue(triggerSessions1.isEmpty)

    // When
    await NotificationCenter.default.post(Notification(name: UIApplication.willEnterForegroundNotification))

    try? await Task.sleep(nanoseconds: 100_000_000)
    // Then
    let triggerSessions2 = await queue.triggerSessions
    
    try? await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertEqual(triggerSessions2.count, 1)
    XCTAssertNotEqual(triggerSessions2.last?.id, lastTriggerSession.id)
    XCTAssertNil(triggerSessions2.last!.endAt)
  }
}
