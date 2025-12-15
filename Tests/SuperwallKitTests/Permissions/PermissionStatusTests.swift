//
//  PermissionStatusTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 2024.
//

import XCTest
@testable import SuperwallKit

final class PermissionStatusTests: XCTestCase {
  func test_fromRaw_granted_returns_granted() {
    let result = PermissionStatus.fromRaw("granted")
    XCTAssertEqual(result, .granted)
  }

  func test_fromRaw_denied_returns_denied() {
    let result = PermissionStatus.fromRaw("denied")
    XCTAssertEqual(result, .denied)
  }

  func test_fromRaw_unsupported_returns_unsupported() {
    let result = PermissionStatus.fromRaw("unsupported")
    XCTAssertEqual(result, .unsupported)
  }

  func test_fromRaw_unknown_returns_nil() {
    let result = PermissionStatus.fromRaw("unknown_status")
    XCTAssertNil(result)
  }

  func test_rawValue_granted_is_correct() {
    XCTAssertEqual(PermissionStatus.granted.rawValue, "granted")
  }

  func test_rawValue_denied_is_correct() {
    XCTAssertEqual(PermissionStatus.denied.rawValue, "denied")
  }

  func test_rawValue_unsupported_is_correct() {
    XCTAssertEqual(PermissionStatus.unsupported.rawValue, "unsupported")
  }

  func test_decodable_granted() throws {
    let json = """
    "granted"
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let result = try decoder.decode(PermissionStatus.self, from: json)
    XCTAssertEqual(result, .granted)
  }

  func test_decodable_denied() throws {
    let json = """
    "denied"
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let result = try decoder.decode(PermissionStatus.self, from: json)
    XCTAssertEqual(result, .denied)
  }

  func test_decodable_unsupported() throws {
    let json = """
    "unsupported"
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let result = try decoder.decode(PermissionStatus.self, from: json)
    XCTAssertEqual(result, .unsupported)
  }
}
