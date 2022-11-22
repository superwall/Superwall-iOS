//
//  TransactionManagerTests.swift
//  
//
//  Created by Yusuf Tör on 31/05/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

@available(iOS 14.0, *)
final class TransactionRecorderTests: XCTestCase {
  func testRecordTransaction() async {
    let configRequestId = "abc"
    let configManager = ConfigManager()
    configManager.config = .stub()

    let queue = MockSessionEventsQueue()
    let sessionEventsManager = SessionEventsManager(
      queue: queue,
      configManager: configManager
    )

    let appSessionId = "123"
    let appSession = AppSession.stub()
      .setting(\.id, to: appSessionId)
    let appSessionManager = AppSessionManagerMock(appSession: appSession)

    let transactionRecorder = TransactionRecorder(
      configManager: configManager,
      sessionEventsManager: sessionEventsManager,
      appSessionManager: appSessionManager
    )

    let transaction = MockSKPaymentTransaction(state: .purchased)
    await transactionRecorder.record(transaction)

    try? await Task.sleep(nanoseconds: 10_000_000)

    let isTransactionsEmpty = await queue.transactions.isEmpty
    XCTAssertFalse(isTransactionsEmpty)
  }
}
