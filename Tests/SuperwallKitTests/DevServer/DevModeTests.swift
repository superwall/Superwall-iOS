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

  private func options(devMode: Bool = false, devServerURL: URL? = nil) -> SuperwallOptions {
    let options = SuperwallOptions()
    options.devMode = devMode
    options.devServerURL = devServerURL
    return options
  }

  func test_isInactiveWhenNobodyAskedForIt() {
    DevMode.isSandboxEnvironment = { true }
    XCTAssertFalse(DevMode.isActive(options()))
  }

  func test_isActiveInSandboxWhenTheToggleIsOn() {
    DevMode.isSandboxEnvironment = { true }
    XCTAssertTrue(DevMode.isActive(options(devMode: true)))
  }

  /// The one that matters: an App Store build must behave as if dev mode was
  /// never set, so purchases stay real and paywalls stay published.
  func test_isInertInProductionEvenWhenTheToggleIsOn() {
    DevMode.isSandboxEnvironment = { false }
    XCTAssertFalse(DevMode.isActive(options(devMode: true)))
  }

  func test_anExplicitDevServerUrlAlsoImpliesDevModeAndIsAlsoGated() throws {
    let url = try XCTUnwrap(URL(string: "http://192.168.1.10:6100"))

    DevMode.isSandboxEnvironment = { true }
    XCTAssertTrue(DevMode.isActive(options(devServerURL: url)))

    DevMode.isSandboxEnvironment = { false }
    XCTAssertFalse(DevMode.isActive(options(devServerURL: url)))
  }
}
