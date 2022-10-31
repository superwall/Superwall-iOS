//
//  AppSessionManagerTests.swift
//  
//
//  Created by Yusuf Tör on 19/05/2022.
//
// swiftlint:disable all

import XCTest
@testable import Superwall

class AppSessionManagerTests: XCTestCase {
  func testAppWillResignActive() async {
    let appManager = AppSessionManager()
    XCTAssertNil(appManager.appSession.endAt)
    
    try? await Task.sleep(nanoseconds: 10_000_000)

    await NotificationCenter.default.post(
      Notification(name: UIApplication.willResignActiveNotification)
    )
    try? await Task.sleep(nanoseconds: 10_000_000)

    XCTAssertNotNil(appManager.appSession.endAt)
  }

  func testAppWillTerminate() async {
    let appManager = AppSessionManager()
    XCTAssertNil(appManager.appSession.endAt)

    try? await Task.sleep(nanoseconds: 10_000_000)

    await NotificationCenter.default.post(
      Notification(name: UIApplication.willTerminateNotification)
    )
    try? await Task.sleep(nanoseconds: 10_000_000)

    XCTAssertNotNil(appManager.appSession.endAt)
  }

  func testAppWillBecomeActive_newSession() async {
    let appManager = AppSessionManager()
    let oldAppSession = appManager.appSession

    try? await Task.sleep(nanoseconds: 10_000_000)

    await NotificationCenter.default.post(
      Notification(name: UIApplication.didBecomeActiveNotification)
    )

    XCTAssertNotEqual(appManager.appSession.id, oldAppSession.id)
  }

  func testAppWillBecomeActive_closeAndOpen() async {
    let appManager = AppSessionManager()
    let oldAppSession = appManager.appSession

    try? await Task.sleep(nanoseconds: 10_000_000)

    await NotificationCenter.default.post(
      Notification(name: UIApplication.willResignActiveNotification)
    )
    try? await Task.sleep(nanoseconds: 10_000_000)

    XCTAssertNotNil(appManager.appSession.endAt)

    await NotificationCenter.default.post(
      Notification(name: UIApplication.didBecomeActiveNotification)
    )

    try? await Task.sleep(nanoseconds: 10_000_000)

    XCTAssertNil(appManager.appSession.endAt)

    XCTAssertEqual(appManager.appSession.id, oldAppSession.id)
  }
}
