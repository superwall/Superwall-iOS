//
//  Email.swift
//  SuperwallKit
//

import Foundation

/// A validated email address.
///
/// The failable initializer rejects any string that does not match the
/// pattern expected by the checkout API (`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`).
/// Holding an `Email` instance proves the value was validated — downstream
/// code never needs to re-check.
struct Email: Equatable, Sendable {
  let rawValue: String

  private static let regex = try! NSRegularExpression(
    pattern: #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
  )

  /// Returns `nil` when `rawValue` is not a syntactically valid email address.
  init?(_ rawValue: String) {
    let range = NSRange(rawValue.startIndex..., in: rawValue)
    guard Self.regex.firstMatch(in: rawValue, range: range) != nil else {
      return nil
    }
    self.rawValue = rawValue
  }
}
