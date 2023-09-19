//
//  File.swift
//  
//
//  Created by Yusuf Tör on 15/09/2023.
//
// swiftlint:disable all

import XCTest
import Combine
@testable import SuperwallKit

@available(iOS 14.0, *)
final class DeviceHelperTests: XCTestCase {
  func test_makePaddedSdkVersion_withBeta() {
    let version = "3.0.0-beta.1"
    let paddedVersion = DeviceHelper.makePaddedSdkVersion(using: version)
    XCTAssertEqual(paddedVersion, "003.000.000-beta.001")
  }

  func test_makePaddedSdkVersion_patchVersion() {
    let version = "3.0.1"
    let paddedVersion = DeviceHelper.makePaddedSdkVersion(using: version)
    XCTAssertEqual(paddedVersion, "003.000.001")
  }

  func test_makePaddedSdkVersion_minorVersion() {
    let version = "3.1.1"
    let paddedVersion = DeviceHelper.makePaddedSdkVersion(using: version)
    XCTAssertEqual(paddedVersion, "003.001.001")
  }

  func test_makePaddedSdkVersion_biggerMinorVersion() {
    let version = "3.10.1"
    let paddedVersion = DeviceHelper.makePaddedSdkVersion(using: version)
    XCTAssertEqual(paddedVersion, "003.010.001")
  }

  func test_makePaddedSdkVersion_rc() {
    let version = "3.10.1-rc.30"
    let paddedVersion = DeviceHelper.makePaddedSdkVersion(using: version)
    XCTAssertEqual(paddedVersion, "003.010.001-rc.030")
  }

  func test_makePaddedSdkVersion_limit() {
    let version = "312.123.123-rc.310"
    let paddedVersion = DeviceHelper.makePaddedSdkVersion(using: version)
    XCTAssertEqual(paddedVersion, "312.123.123-rc.310")
  }

  func test_makePaddedSdkVersion_twoComponents() {
    let version = "3.0"
    let paddedVersion = DeviceHelper.makePaddedSdkVersion(using: version)
    XCTAssertEqual(paddedVersion, "003.000")
  }

  func test_makePaddedSdkVersion_oneComponents() {
    let version = "3"
    let paddedVersion = DeviceHelper.makePaddedSdkVersion(using: version)
    XCTAssertEqual(paddedVersion, "003")
  }
}
