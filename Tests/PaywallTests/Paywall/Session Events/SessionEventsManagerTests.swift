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
    let storage = StorageMock(internalCachedTriggerSessions: [])
    let network = NetworkMock()
    _ = SessionEventsManager(
      storage: storage,
      network: network
    )
    XCTAssertFalse(network.didSendSessionEvents)
    XCTAssertFalse(storage.didClearCachedTriggerSessions)
  }

  func testPostCachedSessionEvents() {
    let storage = StorageMock(internalCachedTriggerSessions: [.stub()])
    let network = NetworkMock()
    _ = SessionEventsManager(
      storage: storage,
      network: network
    )
    XCTAssertTrue(network.didSendSessionEvents)
    XCTAssertTrue(storage.didClearCachedTriggerSessions)
  }
}
