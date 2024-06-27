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
  lazy var dependencyContainer: DependencyContainer = {
    let dependencyContainer = DependencyContainer()
    appSessionManager = AppSessionManager(
      configManager: dependencyContainer.configManager,
      identityManager: dependencyContainer.identityManager,
      storage: dependencyContainer.storage,
      delegate: delegate
    )
    dependencyContainer.appSessionManager = appSessionManager
    return dependencyContainer
  }()
  var appSessionManager: AppSessionManager!
  let delegate = AppManagerDelegateMock()

  override func setUp() {
    _ = dependencyContainer
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

    try? await Task.sleep(nanoseconds: 30_000_000)
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
