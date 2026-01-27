//
//  TestStoreUser.swift
//  Superwall
//
//  Created by Claude on 2026-01-27.
//

import Foundation

/// Identifies a user who should be in test mode.
struct TestStoreUser: Codable, Equatable, Sendable {
  /// The type of identifier used to match the user.
  let type: TestStoreUserType

  /// The identifier value.
  let value: String
}

/// The type of identifier used for test store user matching.
enum TestStoreUserType: String, Codable, Equatable, Sendable {
  case userId
  case vendorId
  case aliasId
}
