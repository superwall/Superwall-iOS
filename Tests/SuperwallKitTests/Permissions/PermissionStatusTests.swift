//
//  PermissionStatusTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 2024.
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite
struct PermissionStatusTests {
  @Test func rawValue_granted_returns_granted() {
    let result = PermissionStatus(rawValue: "granted")
    #expect(result == .granted)
  }

  @Test func rawValue_denied_returns_denied() {
    let result = PermissionStatus(rawValue: "denied")
    #expect(result == .denied)
  }

  @Test func rawValue_unsupported_returns_unsupported() {
    let result = PermissionStatus(rawValue: "unsupported")
    #expect(result == .unsupported)
  }

  @Test func rawValue_unknown_returns_nil() {
    let result = PermissionStatus(rawValue: "unknown_status")
    #expect(result == nil)
  }

  @Test func decodable_granted() throws {
    let json = """
    "granted"
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let result = try decoder.decode(PermissionStatus.self, from: json)
    #expect(result == .granted)
  }

  @Test func decodable_denied() throws {
    let json = """
    "denied"
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let result = try decoder.decode(PermissionStatus.self, from: json)
    #expect(result == .denied)
  }

  @Test func decodable_unsupported() throws {
    let json = """
    "unsupported"
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let result = try decoder.decode(PermissionStatus.self, from: json)
    #expect(result == .unsupported)
  }
}
