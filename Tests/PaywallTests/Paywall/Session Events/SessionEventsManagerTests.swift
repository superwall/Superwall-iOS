//
//  SessionEventsManagerTests.swift
//  
//
//  Created by Yusuf Tör on 27/05/2022.
//
// swiftlint:disable all

import XCTest
@testable import Paywall

@available(iOS 14.0, *)
final class SessionEventsManagerTests: XCTestCase {
  // MARK: - PostCachedSessionEvents
  func testPostCachedSessionEvents_noneAvailable() async {
    let storage = StorageMock(
      internalCachedTriggerSessions: [],
      internalCachedTransactions: []
    )
    let network = NetworkMock()
    _ = SessionEventsManager(
      storage: storage,
      network: network
    )

    let twoHundredMilliseconds = UInt64(200_000_000)
    try? await Task.sleep(nanoseconds: twoHundredMilliseconds)

    XCTAssertNil(network.sentSessionEvents)
    XCTAssertFalse(storage.didClearCachedSessionEvents)
  }

  func testPostCachedSessionEvents_triggerSessionsOnly() async {
    let storage = StorageMock(internalCachedTriggerSessions: [.stub()])
    let configManager = ConfigManager()
    configManager.config = .stub()

    let network = NetworkMock()
    _ = SessionEventsManager(
      storage: storage,
      network: network,
      configManager: configManager
    )

    let twoHundredMilliseconds = UInt64(200_000_000)
    try? await Task.sleep(nanoseconds: twoHundredMilliseconds)

    XCTAssertTrue(network.sentSessionEvents!.transactions.isEmpty)
    XCTAssertFalse(network.sentSessionEvents!.triggerSessions.isEmpty)
    XCTAssertTrue(storage.didClearCachedSessionEvents)
  }

  func testPostCachedSessionEvents_triggerSessionsAndTransactions() async {
    let storage = StorageMock(
      internalCachedTriggerSessions: [.stub()],
      internalCachedTransactions: [.stub()]
    )
    let configManager = ConfigManager()
    configManager.config = .stub()

    let network = NetworkMock()
    _ = SessionEventsManager(
      storage: storage,
      network: network,
      configManager: configManager
    )

    let twoHundredMilliseconds = UInt64(200_000_000)
    try? await Task.sleep(nanoseconds: twoHundredMilliseconds)

    XCTAssertFalse(network.sentSessionEvents!.transactions.isEmpty)
    XCTAssertFalse(network.sentSessionEvents!.triggerSessions.isEmpty)
    XCTAssertTrue(storage.didClearCachedSessionEvents)
  }

  func testPostCachedSessionEvents_transactionsOnly() async {
    let storage = StorageMock(
      internalCachedTriggerSessions: [],
      internalCachedTransactions: [.stub()]
    )
    let configManager = ConfigManager()
    configManager.config = .stub()

    let network = NetworkMock()
    _ = SessionEventsManager(
      storage: storage,
      network: network,
      configManager: configManager
    )

    let twoHundredMilliseconds = UInt64(200_000_000)
    try? await Task.sleep(nanoseconds: twoHundredMilliseconds)

    XCTAssertFalse(network.sentSessionEvents!.transactions.isEmpty)
    XCTAssertTrue(network.sentSessionEvents!.triggerSessions.isEmpty)
    XCTAssertTrue(storage.didClearCachedSessionEvents)
  }
}
