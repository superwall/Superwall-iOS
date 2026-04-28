//
//  Email.swift
//  SuperwallKit
//

import Foundation

/// A validated email address.
///
/// The failable initializer rejects any string that does not match the
/// pattern expected by the checkout API (`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\z`).
/// Holding an `Email` instance proves the value was validated — downstream
/// code never needs to re-check.
struct Email: Equatable, Sendable {
  let rawValue: String

  // `\z` (not `$`) is used so that a trailing `\n` is rejected — ICU treats `$`
  // as matching at end-of-string *or* just before a final newline.
  // Pattern is a validated literal — initialization can never throw at runtime.
  private static let regex = try! NSRegularExpression( // swiftlint:disable:this force_try
    pattern: #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\z"#
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
