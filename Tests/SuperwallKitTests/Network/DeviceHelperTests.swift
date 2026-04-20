//
//  File.swift
//
//
//  Created by Yusuf Tör on 15/09/2023.
//
// swiftlint:disable all

import Testing
import Combine
@testable import SuperwallKit

struct DeviceHelperTests {
  @Test func makePaddedSdkVersion_withBeta() {
    let version = "3.0.0-beta.1"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "003.000.000-beta.001")
  }

  @Test func makePaddedSdkVersion_patchVersion() {
    let version = "3.0.1"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "003.000.001")
  }

  @Test func makePaddedSdkVersion_minorVersion() {
    let version = "3.1.1"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "003.001.001")
  }

  @Test func makePaddedSdkVersion_biggerMinorVersion() {
    let version = "3.10.1"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "003.010.001")
  }

  @Test func makePaddedSdkVersion_rc() {
    let version = "3.10.1-rc.30"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "003.010.001-rc.030")
  }

  @Test func makePaddedSdkVersion_limit() {
    let version = "312.123.123-rc.310"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "312.123.123-rc.310")
  }

  @Test func makePaddedSdkVersion_twoComponents() {
    let version = "3.0"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "003.000")
  }

  @Test func makePaddedSdkVersion_oneComponents() {
    let version = "3"
    let paddedVersion = DeviceHelper.makePaddedVersion(using: version)
    #expect(paddedVersion == "003")
  }
}
