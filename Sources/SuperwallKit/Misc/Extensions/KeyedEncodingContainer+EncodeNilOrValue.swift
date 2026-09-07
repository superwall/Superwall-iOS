//
//  KeyedEncodingContainer+EncodeNilOrValue.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 07/09/2026.
//

import Foundation

extension KeyedEncodingContainer {
  /// Encodes an optional, writing an explicit null when it's `nil`.
  ///
  /// `encodeIfPresent` leaves the key out entirely, which loses the difference
  /// between a value we know to be absent and one we never learned. Audience
  /// filters give a missing key the type default, so a dropped `Bool?` reads as
  /// `false`. Use this for any field a filter might compare by equality.
  mutating func encodeNilOrValue<T: Encodable>(
    _ value: T?,
    forKey key: Key
  ) throws {
    if let value = value {
      try encode(value, forKey: key)
    } else {
      try encodeNil(forKey: key)
    }
  }
}
