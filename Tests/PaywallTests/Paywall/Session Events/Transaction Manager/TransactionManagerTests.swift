//
//  TransactionManagerTests.swift
//  
//
//  Created by Yusuf Tör on 31/05/2022.
//
// swiftlint:disable all

import XCTest
@testable import Paywall

final class TransactionManagerTests: XCTestCase {
  func testRecordTransaction() {
    let queue = SessionEventsQueueMock()
    let delegate = SessionEventsDelegateMock(queue: queue)
    let configRequestId = "abc"
    let storage = StorageMock(configRequestId: configRequestId)

    let appSessionId = "123"
    let appSession = AppSession.stub()
      .setting(\.id, to: appSessionId)
    let appSessionManager = AppSessionManagerMock(appSession: appSession)

    let transactionManager = TransactionManager(
      delegate: delegate,
      storage: storage,
      appSessionManager: appSessionManager
    )

    let transaction = MockSKPaymentTransaction(state: .purchased)
    transactionManager.record(transaction)

    XCTAssertFalse(queue.transactions.isEmpty)
  }
}
