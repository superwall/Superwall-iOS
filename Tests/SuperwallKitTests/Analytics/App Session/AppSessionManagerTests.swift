//
//  AppSessionManagerTests.swift
//  
//
//  Created by Yusuf Tör on 19/05/2022.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

class AppSessionManagerTests: XCTestCase {
  var appSessionManager: AppSessionManager!

  override func setUp() async throws {
    let dependencyContainer = DependencyContainer(apiKey: "abc")
    appSessionManager = dependencyContainer.appSessionManager
  }

  func testAppWillResignActive() async {
    XCTAssertNil(appSessionManager.appSession.endAt)
    
    try? await Task.sleep(nanoseconds: 10_000_000)

    await NotificationCenter.default.post(
      Notification(name: UIApplication.willResignActiveNotification)
    )
    try? await Task.sleep(nanoseconds: 10_000_000)

    XCTAssertNotNil(appSessionManager.appSession.endAt)
  }

  func testAppWillTerminate() async {
    XCTAssertNil(appSessionManager.appSession.endAt)

    try? await Task.sleep(nanoseconds: 10_000_000)

    await NotificationCenter.default.post(
      Notification(name: UIApplication.willTerminateNotification)
    )
    try? await Task.sleep(nanoseconds: 10_000_000)

    XCTAssertNotNil(appSessionManager.appSession.endAt)
  }

  func testAppWillBecomeActive_newSession() async {
    let oldAppSession = appSessionManager.appSession

    try? await Task.sleep(nanoseconds: 10_000_000)

    await NotificationCenter.default.post(
      Notification(name: UIApplication.didBecomeActiveNotification)
    )

    XCTAssertNotEqual(appSessionManager.appSession.id, oldAppSession.id)
  }

  func testAppWillBecomeActive_closeAndOpen() async {
    let oldAppSession = appSessionManager.appSession

    try? await Task.sleep(nanoseconds: 10_000_000)

    await NotificationCenter.default.post(
      Notification(name: UIApplication.willResignActiveNotification)
    )
    try? await Task.sleep(nanoseconds: 10_000_000)

    XCTAssertNotNil(appSessionManager.appSession.endAt)

    await NotificationCenter.default.post(
      Notification(name: UIApplication.didBecomeActiveNotification)
    )

    try? await Task.sleep(nanoseconds: 10_000_000)

    XCTAssertNil(appSessionManager.appSession.endAt)

    XCTAssertEqual(appSessionManager.appSession.id, oldAppSession.id)
  }
}
