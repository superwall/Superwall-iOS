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
    // Given
    let dependencyContainer = DependencyContainer(apiKey: "")

    let queue = MockSessionEventsQueue()
    let sessionEventsManager = SessionEventsManager(
      queue: queue,
      storage: Storage(),
      network: Network(factory: dependencyContainer),
      configManager:  dependencyContainer.configManager,
      factory: dependencyContainer
    )

    let appSessionId = "123"
    let appSession = AppSession.stub()
      .setting(\.id, to: appSessionId)
    let appSessionManager = AppSessionManagerMock(
      appSession: appSession,
      configManager: dependencyContainer.configManager,
      storage: dependencyContainer.storage
    )
    dependencyContainer.appSessionManager = appSessionManager
    dependencyContainer.sessionEventsManager = sessionEventsManager

    let productPurchaser = dependencyContainer.makeSK1ProductPurchaser()
    let paymentQueue = SKPaymentQueue.default()

    // When
    let transaction = MockSKPaymentTransaction(state: .purchased)
    productPurchaser.paymentQueue(paymentQueue, updatedTransactions: [transaction])

    try? await Task.sleep(nanoseconds: 10_000_000)

    // Then
    let isTransactionsEmpty = await queue.transactions.isEmpty
    XCTAssertFalse(isTransactionsEmpty)
  }
}
