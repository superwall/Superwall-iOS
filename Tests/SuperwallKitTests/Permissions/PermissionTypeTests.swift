//
//  PermissionTypeTests.swift
//  SuperwallKitTests
//
//  Created by Superwall on 2024.
//

import Foundation
import Testing
@testable import SuperwallKit

@Suite
struct PermissionTypeTests {
  @Test func rawValue_notification_returns_notification() {
    let result = PermissionType(rawValue: "notification")
    #expect(result == .notification)
  }

  @Test func rawValue_unknown_returns_nil() {
    let result = PermissionType(rawValue: "unknown_permission")
    #expect(result == nil)
  }

  @Test func rawValue_notification_is_correct() {
    #expect(PermissionType.notification.rawValue == "notification")
  }

  @Test func rawValue_backgroundLocation_is_snake_case() {
    #expect(PermissionType.backgroundLocation.rawValue == "background_location")
  }

  @Test func rawValue_readImages_is_snake_case() {
    #expect(PermissionType.readImages.rawValue == "read_images")
  }

  @Test func decodable_notification() throws {
    let json = """
    "notification"
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let result = try decoder.decode(PermissionType.self, from: json)
    #expect(result == .notification)
  }

  @Test func decodable_unknown_throws() {
    let json = """
    "unknown"
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    #expect(throws: Error.self) {
      try decoder.decode(PermissionType.self, from: json)
    }
  }
}
