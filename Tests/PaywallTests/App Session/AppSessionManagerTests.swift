//
//  AppSessionManagerTests.swift
//  
//
//  Created by Yusuf Tör on 19/05/2022.
//

import XCTest
@testable import Paywall

class AppSessionManagerTests: XCTestCase {
  func testAppWillResignActive() {
    let queue = SessionEventsQueueMock()
    let sessionEvents = SessionEventsManager(queue: queue)
    let appManager = AppSessionManager(
      sessionEventsManager: sessionEvents
    )
    XCTAssertNil(appManager.appSession.endAt)

    NotificationCenter.default.post(
      Notification(name: UIApplication.willResignActiveNotification)
    )

    XCTAssertNotNil(appManager.appSession.endAt)
  }

  func testAppWillTerminate() {
    let queue = SessionEventsQueueMock()
    let sessionEvents = SessionEventsManager(queue: queue)
    let appManager = AppSessionManager(
      sessionEventsManager: sessionEvents
    )
    XCTAssertNil(appManager.appSession.endAt)

    NotificationCenter.default.post(
      Notification(name: UIApplication.willTerminateNotification)
    )

    XCTAssertNotNil(appManager.appSession.endAt)
  }

  func testAppWillBecomeActive_newSession() {
    let queue = SessionEventsQueueMock()
    let sessionEvents = SessionEventsManager(queue: queue)
    let appManager = AppSessionManager(
      sessionEventsManager: sessionEvents
    )
    let oldAppSession = appManager.appSession

    NotificationCenter.default.post(
      Notification(name: UIApplication.didBecomeActiveNotification)
    )

    XCTAssertNotEqual(appManager.appSession.id, oldAppSession.id)
  }

  func testAppWillBecomeActive_closeAndOpen() {
    let queue = SessionEventsQueueMock()
    let sessionEvents = SessionEventsManager(queue: queue)
    let appManager = AppSessionManager(
      sessionEventsManager: sessionEvents
    )
    let oldAppSession = appManager.appSession

    NotificationCenter.default.post(
      Notification(name: UIApplication.willResignActiveNotification)
    )
    XCTAssertNotNil(appManager.appSession.endAt)

    NotificationCenter.default.post(
      Notification(name: UIApplication.didBecomeActiveNotification)
    )
    XCTAssertNil(appManager.appSession.endAt)

    XCTAssertEqual(appManager.appSession.id, oldAppSession.id)
  }
}
