//
//  PermissionTypeTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 2024.
//

import XCTest
@testable import SuperwallKit

final class PermissionTypeTests: XCTestCase {
  func test_fromRaw_notification_returns_notification() {
    let result = PermissionType.fromRaw("notification")
    XCTAssertEqual(result, .notification)
  }

  func test_fromRaw_unknown_returns_nil() {
    let result = PermissionType.fromRaw("unknown_permission")
    XCTAssertNil(result)
  }

  func test_rawValue_notification_is_correct() {
    let permissionType = PermissionType.notification
    XCTAssertEqual(permissionType.rawValue, "notification")
  }

  func test_decodable_notification() throws {
    let json = """
    "notification"
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let result = try decoder.decode(PermissionType.self, from: json)
    XCTAssertEqual(result, .notification)
  }

  func test_decodable_unknown_throws() {
    let json = """
    "unknown"
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    XCTAssertThrowsError(try decoder.decode(PermissionType.self, from: json))
  }
}
