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
  var dependencyContainer: DependencyContainer!
  var appSessionManager: AppSessionManager!
  let delegate = AppManagerDelegateMock()

  override func setUp() {
    // Create fresh instances for each test to ensure isolation
    dependencyContainer = DependencyContainer()
    appSessionManager = AppSessionManager(
      configManager: dependencyContainer.configManager,
      identityManager: dependencyContainer.identityManager,
      storage: dependencyContainer.storage,
      delegate: delegate
    )
    dependencyContainer.appSessionManager = appSessionManager
  }
  
  override func tearDown() {
    appSessionManager = nil
    dependencyContainer = nil
  }

  func testAppWillResignActive() async {
    XCTAssertNil(appSessionManager.appSession.endAt)

    try? await Task.sleep(nanoseconds: 50_000_000)

    await NotificationCenter.default.post(
      Notification(name: UIApplication.willResignActiveNotification)
    )
    try? await Task.sleep(nanoseconds: 50_000_000)

    XCTAssertNotNil(appSessionManager.appSession.endAt)
  }

  func testAppWillTerminate() async {
    XCTAssertNil(appSessionManager.appSession.endAt)

    try? await Task.sleep(nanoseconds: 10_000_000)

    await NotificationCenter.default.post(
      Notification(name: UIApplication.willTerminateNotification)
    )
    try? await Task.sleep(nanoseconds: 50_000_000)

    XCTAssertNotNil(appSessionManager.appSession.endAt)
  }

  func testAppWillBecomeActive_newSession() async {
    let oldAppSession = appSessionManager.appSession
    dependencyContainer.configManager.configState.send(.retrieved(.stub()))
    try? await Task.sleep(nanoseconds: 10_000_000)

    await NotificationCenter.default.post(
      Notification(name: UIApplication.didBecomeActiveNotification)
    )

    // Poll for session ID to change with timeout (more robust than fixed sleep)
    let startTime = Date()
    let timeout: TimeInterval = 1.0
    while appSessionManager.appSession.id == oldAppSession.id {
      if Date().timeIntervalSince(startTime) > timeout {
        break
      }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }

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

    // Poll for endAt to become nil with timeout (more robust than fixed sleep)
    let startTime = Date()
    let timeout: TimeInterval = 1.0
    while appSessionManager.appSession.endAt != nil {
      if Date().timeIntervalSince(startTime) > timeout {
        break
      }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }

    XCTAssertNil(appSessionManager.appSession.endAt)

    XCTAssertEqual(appSessionManager.appSession.id, oldAppSession.id)
  }
}
