//
//  DynamicIslandInfoTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 01/12/2024.
//
// swiftlint:disable type_body_length file_length

#if !os(visionOS)
@testable import SuperwallKit
import XCTest

final class DynamicIslandInfoTests: XCTestCase {
  // MARK: - Constants

  /// Expected width for 230pt Dynamic Island devices
  private let width230: CGFloat = 230 - (52.33 * 2) // 125.34pt

  /// Expected width for 250pt Dynamic Island devices
  private let width250: CGFloat = 250 - (62.33 * 2) // 125.34pt

  /// Expected height for all Dynamic Island devices
  private let dynamicIslandHeight: CGFloat = 36.67

  // MARK: - 230pt Dynamic Island Devices

  func test_iPhone14Pro() {
    let info = DynamicIslandInfo(for: "iPhone15,2")
    XCTAssertTrue(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, width230)
    XCTAssertEqual(info.height, dynamicIslandHeight)
    XCTAssertEqual(info.topPadding, 11)
  }

  func test_iPhone15() {
    let info = DynamicIslandInfo(for: "iPhone15,4")
    XCTAssertTrue(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, width230)
    XCTAssertEqual(info.height, dynamicIslandHeight)
    XCTAssertEqual(info.topPadding, 11)
  }

  func test_iPhone15Pro() {
    let info = DynamicIslandInfo(for: "iPhone16,1")
    XCTAssertTrue(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, width230)
    XCTAssertEqual(info.height, dynamicIslandHeight)
    XCTAssertEqual(info.topPadding, 11)
  }

  func test_iPhone16Pro() {
    let info = DynamicIslandInfo(for: "iPhone17,1")
    XCTAssertTrue(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, width230)
    XCTAssertEqual(info.height, dynamicIslandHeight)
    XCTAssertEqual(info.topPadding, 14)
  }

  func test_iPhone16() {
    let info = DynamicIslandInfo(for: "iPhone17,3")
    XCTAssertTrue(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, width230)
    XCTAssertEqual(info.height, dynamicIslandHeight)
    XCTAssertEqual(info.topPadding, 11)
  }

  func test_iPhone17Pro() {
    let info = DynamicIslandInfo(for: "iPhone18,1")
    XCTAssertTrue(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, width230)
    XCTAssertEqual(info.height, dynamicIslandHeight)
    XCTAssertEqual(info.topPadding, 14)
  }

  func test_iPhone17() {
    let info = DynamicIslandInfo(for: "iPhone18,3")
    XCTAssertTrue(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, width230)
    XCTAssertEqual(info.height, dynamicIslandHeight)
    XCTAssertEqual(info.topPadding, 14)
  }

  // MARK: - 250pt Dynamic Island Devices

  func test_iPhone14ProMax() {
    let info = DynamicIslandInfo(for: "iPhone15,3")
    XCTAssertTrue(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, width250)
    XCTAssertEqual(info.height, dynamicIslandHeight)
    XCTAssertEqual(info.topPadding, 11)
  }

  func test_iPhone15Plus() {
    let info = DynamicIslandInfo(for: "iPhone15,5")
    XCTAssertTrue(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, width250)
    XCTAssertEqual(info.height, dynamicIslandHeight)
    XCTAssertEqual(info.topPadding, 11)
  }

  func test_iPhone15ProMax() {
    let info = DynamicIslandInfo(for: "iPhone16,2")
    XCTAssertTrue(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, width250)
    XCTAssertEqual(info.height, dynamicIslandHeight)
    XCTAssertEqual(info.topPadding, 11)
  }

  func test_iPhone16ProMax() {
    let info = DynamicIslandInfo(for: "iPhone17,2")
    XCTAssertTrue(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, width250)
    XCTAssertEqual(info.height, dynamicIslandHeight)
    XCTAssertEqual(info.topPadding, 14)
  }

  func test_iPhone16Plus() {
    let info = DynamicIslandInfo(for: "iPhone17,4")
    XCTAssertTrue(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, width250)
    XCTAssertEqual(info.height, dynamicIslandHeight)
    XCTAssertEqual(info.topPadding, 11)
  }

  func test_iPhone17ProMax() {
    let info = DynamicIslandInfo(for: "iPhone18,2")
    XCTAssertTrue(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, width250)
    XCTAssertEqual(info.height, dynamicIslandHeight)
    XCTAssertEqual(info.topPadding, 14)
  }

  func test_iPhoneAir() {
    let info = DynamicIslandInfo(for: "iPhone18,4")
    XCTAssertTrue(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, width250)
    XCTAssertEqual(info.height, dynamicIslandHeight)
    XCTAssertEqual(info.topPadding, 20)
  }

  // MARK: - Notch Devices

  func test_iPhoneX() {
    let info = DynamicIslandInfo(for: "iPhone10,3")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhoneXS() {
    let info = DynamicIslandInfo(for: "iPhone11,2")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhoneXSMax() {
    let info = DynamicIslandInfo(for: "iPhone11,4")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhoneXR() {
    let info = DynamicIslandInfo(for: "iPhone11,8")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhone11() {
    let info = DynamicIslandInfo(for: "iPhone12,1")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhone11Pro() {
    let info = DynamicIslandInfo(for: "iPhone12,3")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhone11ProMax() {
    let info = DynamicIslandInfo(for: "iPhone12,5")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhone12Mini() {
    let info = DynamicIslandInfo(for: "iPhone13,1")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhone12() {
    let info = DynamicIslandInfo(for: "iPhone13,2")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhone12Pro() {
    let info = DynamicIslandInfo(for: "iPhone13,3")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhone12ProMax() {
    let info = DynamicIslandInfo(for: "iPhone13,4")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhone13Mini() {
    let info = DynamicIslandInfo(for: "iPhone14,4")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhone13() {
    let info = DynamicIslandInfo(for: "iPhone14,5")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhone13Pro() {
    let info = DynamicIslandInfo(for: "iPhone14,2")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhone13ProMax() {
    let info = DynamicIslandInfo(for: "iPhone14,3")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhone14() {
    let info = DynamicIslandInfo(for: "iPhone14,7")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhone14Plus() {
    let info = DynamicIslandInfo(for: "iPhone14,8")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_iPhone16e() {
    let info = DynamicIslandInfo(for: "iPhone17,5")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertTrue(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  // MARK: - Unknown Devices

  func test_unknownDevice_iPad() {
    let info = DynamicIslandInfo(for: "iPad13,1")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_unknownDevice_simulator() {
    let info = DynamicIslandInfo(for: "x86_64")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  func test_unknownDevice_futureDevice() {
    let info = DynamicIslandInfo(for: "iPhone99,1")
    XCTAssertFalse(info.hasDynamicIsland)
    XCTAssertFalse(info.hasNotch)
    XCTAssertEqual(info.width, 0)
    XCTAssertEqual(info.height, 0)
    XCTAssertEqual(info.topPadding, 0)
  }

  // MARK: - Computed Properties

  func test_hasDynamicIslandOrNotch_dynamicIsland() {
    let info = DynamicIslandInfo(for: "iPhone15,2")
    XCTAssertTrue(info.hasDynamicIslandOrNotch)
  }

  func test_hasDynamicIslandOrNotch_notch() {
    let info = DynamicIslandInfo(for: "iPhone14,7")
    XCTAssertTrue(info.hasDynamicIslandOrNotch)
  }

  func test_hasDynamicIslandOrNotch_neither() {
    let info = DynamicIslandInfo(for: "iPad13,1")
    XCTAssertFalse(info.hasDynamicIslandOrNotch)
  }
}
#endif
