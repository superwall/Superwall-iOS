//
//  SessionEventsManagerTests.swift
//  
//
//  Created by Yusuf Tör on 27/05/2022.
//

import XCTest
@testable import Paywall

final class SessionEventsManagerTests: XCTestCase {
  // MARK: - PostCachedSessionEvents
  func testPostCachedSessionEvents_noneAvailable() {
    let storage = StorageMock(
      internalCachedTriggerSessions: [],
      internalCachedTransactions: []
    )
    let network = NetworkMock()
    _ = SessionEventsManager(
      storage: storage,
      network: network
    )
    XCTAssertNil(network.sentSessionEvents)
    XCTAssertFalse(storage.didClearCachedSessionEvents)
  }

  func testPostCachedSessionEvents_triggerSessionsOnly() {
    let storage = StorageMock(internalCachedTriggerSessions: [.stub()])
    let network = NetworkMock()
    _ = SessionEventsManager(
      storage: storage,
      network: network
    )
    XCTAssertTrue(network.sentSessionEvents!.transactions.isEmpty)
    XCTAssertFalse(network.sentSessionEvents!.triggerSessions.isEmpty)
    XCTAssertTrue(storage.didClearCachedSessionEvents)
  }

  func testPostCachedSessionEvents_triggerSessionsAndTransactions() {
    let storage = StorageMock(
      internalCachedTriggerSessions: [.stub()],
      internalCachedTransactions: [.stub()]
    )
    let network = NetworkMock()
    _ = SessionEventsManager(
      storage: storage,
      network: network
    )
    XCTAssertFalse(network.sentSessionEvents!.transactions.isEmpty)
    XCTAssertFalse(network.sentSessionEvents!.triggerSessions.isEmpty)
    XCTAssertTrue(storage.didClearCachedSessionEvents)
  }

  func testPostCachedSessionEvents_transactionsOnly() {
    let storage = StorageMock(
      internalCachedTriggerSessions: [],
      internalCachedTransactions: [.stub()]
    )
    let network = NetworkMock()
    _ = SessionEventsManager(
      storage: storage,
      network: network
    )
    XCTAssertFalse(network.sentSessionEvents!.transactions.isEmpty)
    XCTAssertTrue(network.sentSessionEvents!.triggerSessions.isEmpty)
    XCTAssertTrue(storage.didClearCachedSessionEvents)
  }
}
