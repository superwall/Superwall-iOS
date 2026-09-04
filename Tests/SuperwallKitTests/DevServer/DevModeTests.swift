//
//  DevModeTests.swift
//  SuperwallKitTests
//

import XCTest
@testable import SuperwallKit

final class DevModeTests: XCTestCase {
  override func tearDown() {
    DevMode.isSandboxEnvironment = { DeviceHelper.isSandboxEnvironment }
    super.tearDown()
  }

  private func options(devServer: SuperwallOptions.DevServer? = nil) -> SuperwallOptions {
    let options = SuperwallOptions()
    options.devServer = devServer
    return options
  }

  func test_isInactiveWhenNobodyAskedForIt() {
    DevMode.isSandboxEnvironment = { true }
    XCTAssertFalse(DevMode.isActive(options()))
  }

  func test_isActiveInSandboxWhenTheToggleIsOn() {
    DevMode.isSandboxEnvironment = { true }
    XCTAssertTrue(DevMode.isActive(options(devServer: .default)))
  }

  /// The one that matters: an App Store build must behave as if dev mode was
  /// never set, so purchases stay real and paywalls stay published.
  func test_isInertInProductionEvenWhenTheToggleIsOn() {
    DevMode.isSandboxEnvironment = { false }
    XCTAssertFalse(DevMode.isActive(options(devServer: .default)))
  }

  func test_anExplicitDevServerUrlIsAlsoGated() throws {
    let url = try XCTUnwrap(URL(string: "http://192.168.1.10:6100"))

    DevMode.isSandboxEnvironment = { true }
    XCTAssertTrue(DevMode.isActive(options(devServer: .url(url))))

    DevMode.isSandboxEnvironment = { false }
    XCTAssertFalse(DevMode.isActive(options(devServer: .url(url))))
  }
}
