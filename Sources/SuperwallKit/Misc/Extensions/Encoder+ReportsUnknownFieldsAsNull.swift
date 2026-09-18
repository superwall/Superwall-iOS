//
//  Encoder+ReportsUnknownFieldsAsNull.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 07/09/2026.
//

import Foundation

extension CodingUserInfoKey {
  /// Set on an encoder to write a field we have no value for as an explicit
  /// null instead of leaving the key out.
  ///
  /// Only the audience filter attributes are encoded this way. A filter gives a
  /// missing key the type default, so a dropped `Bool?` reads as `false` and a
  /// bare Purchase Controller entitlement matched `willRenew == false`. Every
  /// other consumer — the enrichment request, paywall template variables,
  /// session attributes and `getDeviceAttributes()` — keeps the shape it has
  /// always had.
  // swiftlint:disable:next force_unwrapping
  static let reportsUnknownFieldsAsNull = CodingUserInfoKey(rawValue: "reportsUnknownFieldsAsNull")!
}

extension Encoder {
  /// Whether this encoder wants unknown fields written as explicit nulls.
  var reportsUnknownFieldsAsNull: Bool {
    userInfo[.reportsUnknownFieldsAsNull] as? Bool ?? false
  }
}

extension JSONEncoder {
  /// An encoder that writes unknown optional fields as explicit nulls.
  static func reportingUnknownFieldsAsNull() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.userInfo[.reportsUnknownFieldsAsNull] = true
    return encoder
  }
}

extension KeyedEncodingContainer {
  /// Encodes an optional, either leaving the key out when it's `nil` or writing
  /// an explicit null, depending on what the encoder asked for.
  ///
  /// Plain `encode(_:forKey:)` on an optional already writes a null, since
  /// `Optional`'s own `Encodable` conformance calls `encodeNil()`. Spelling it
  /// out keeps the two behaviours side by side at the call site.
  mutating func encode<T: Encodable>(
    _ value: T?,
    forKey key: Key,
    nilAsNull: Bool
  ) throws {
    if let value = value {
      try encode(value, forKey: key)
    } else if nilAsNull {
      try encodeNil(forKey: key)
    }
  }
}
