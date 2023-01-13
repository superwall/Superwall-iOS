//
//  File.swift
//  
//
//  Created by Yusuf Tör on 13/01/2023.
//


import XCTest
@testable import SuperwallKit
import StoreKit

@available(iOS 14.0, *)
final class ProductPurchaserSK1Tests: XCTestCase {
  let dependencyContainer = DependencyContainer(apiKey: "")
  var sessionEventsManager: SessionEventsManager!
  
  func test_recordTransaction() async {
    // Given
    let appSessionId = "123"
    let appSession = AppSession.stub()
      .setting(\.id, to: appSessionId)
    let appSessionManager = AppSessionManagerMock(
      appSession: appSession,
      configManager: dependencyContainer.configManager,
      storage: dependencyContainer.storage
    )

    let queue = MockSessionEventsQueue()
    sessionEventsManager = SessionEventsManager(
      queue: queue,
      storage: dependencyContainer.storage,
      network: Network(factory: dependencyContainer),
      configManager:  dependencyContainer.configManager,
      factory: dependencyContainer
    )
    dependencyContainer.sessionEventsManager = sessionEventsManager
    sessionEventsManager.postInit()
    appSessionManager.postInit(sessionEventsManager: sessionEventsManager)
    dependencyContainer.appSessionManager = appSessionManager

    dependencyContainer.configManager.config =  .stub()

    let productPurchaser = ProductPurchaserSK1(
      storeKitManager: dependencyContainer.storeKitManager,
      sessionEventsManager: sessionEventsManager,
      delegateAdapter: dependencyContainer.delegateAdapter,
      factory: dependencyContainer
    )
    let paymentQueue = SKPaymentQueue.default()

    // When
    let transaction = MockSKPaymentTransaction(state: .purchased)
    productPurchaser.paymentQueue(paymentQueue, updatedTransactions: [transaction])

    try? await Task.sleep(nanoseconds: 100_000_000)

    // Then
    let isTransactionsEmpty = await queue.transactions.isEmpty
    XCTAssertFalse(isTransactionsEmpty)
  }
}
