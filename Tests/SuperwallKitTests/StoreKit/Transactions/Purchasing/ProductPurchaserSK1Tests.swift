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
  func test_recordTransaction() async {
    // MARK: Given
    let dependencyContainer = DependencyContainer(apiKey: "")
    
    // Set up App Session
    let appSessionId = "123"
    let appSession = AppSession.stub()
      .setting(\.id, to: appSessionId)
    let appSessionManager = AppSessionManagerMock(
      appSession: appSession,
      configManager: dependencyContainer.configManager,
      storage: dependencyContainer.storage
    )

    // Set up Session Events Manager
    let queue = MockSessionEventsQueue()
    let sessionEventsManager = SessionEventsManager(
      queue: queue,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      configManager:  dependencyContainer.configManager,
      factory: dependencyContainer
    )

    // Switch dependency container properties
    dependencyContainer.sessionEventsManager = sessionEventsManager
    dependencyContainer.appSessionManager = appSessionManager
    // Sleeping so that old managers  can deinit
    try? await Task.sleep(nanoseconds: 1000_000_000)

    // Fire postInits
    sessionEventsManager.postInit()
    appSessionManager.postInit(sessionEventsManager: sessionEventsManager)

    dependencyContainer.configManager.config =  .stub()

    let productPurchaser = ProductPurchaserSK1(
      storeKitManager: dependencyContainer.storeKitManager,
      sessionEventsManager: sessionEventsManager,
      delegateAdapter: dependencyContainer.delegateAdapter,
      factory: dependencyContainer
    )
    let paymentQueue = SKPaymentQueue.default()

    // MARK: When
    let transaction = MockSKPaymentTransaction(state: .purchased)
    productPurchaser.paymentQueue(paymentQueue, updatedTransactions: [transaction])

    try? await Task.sleep(nanoseconds: 1000_000_000)

    // MARK: Then
    let isTransactionsEmpty = await queue.transactions.isEmpty

    try? await Task.sleep(nanoseconds: 1000_000_000)
    
    XCTAssertFalse(isTransactionsEmpty)
  }
}
