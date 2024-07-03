//
//  SessionEventsManagerTests.swift
//  
//
//  Created by Yusuf Tör on 27/05/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

@available(iOS 14.0, *)
final class SessionEventsManagerTests: XCTestCase {
  // MARK: - PostCachedSessionEvents
  func testPostCachedSessionEvents_noneAvailable() async {
    let storage = StorageMock(
      internalCachedTransactions: []
    )
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(factory: dependencyContainer)
    _ = SessionEventsManager(
      queue: SessionEventsQueue(
        storage: storage,
        network: network,
        configManager: dependencyContainer.configManager
      ),
      storage: storage,
      network: network,
      configManager: dependencyContainer.configManager
    )

    let milliseconds = 200
    let nanoseconds = UInt64(milliseconds * 1_000_000)
    try? await Task.sleep(nanoseconds: nanoseconds)

    XCTAssertNil(network.sentSessionEvents)
    XCTAssertFalse(storage.didClearCachedSessionEvents)
  }

  func testPostCachedSessionEvents_transactions() async {
    let storage = StorageMock(
      internalCachedTransactions: [.stub()]
    )
    let dependencyContainer = DependencyContainer()
    let configManager = dependencyContainer.configManager!
    configManager.configState.send(.retrieved(.stub()))

    let network = NetworkMock(factory: dependencyContainer)
    _ = SessionEventsManager(
      queue: SessionEventsQueue(
        storage: storage,
        network: network,
        configManager: configManager
      ),
      storage: storage,
      network: network,
      configManager: configManager
    )

    let milliseconds = 200
    let nanoseconds = UInt64(milliseconds * 1_000_000)
    try? await Task.sleep(nanoseconds: nanoseconds)

    XCTAssertFalse(network.sentSessionEvents!.transactions.isEmpty)
    XCTAssertTrue(storage.didClearCachedSessionEvents)
  }
}
