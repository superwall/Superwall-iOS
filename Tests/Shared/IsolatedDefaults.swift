//
//  IsolatedDefaults.swift
//  SuperwallKit
//
//  Created by Superwall on 06/11/2026.
//
// swiftlint:disable all

import Foundation

/// A `UserDefaults` that no other test uses, so tests that save settings
/// can run in parallel with tests that read or clear the same keys.
/// Call `remove()` when the test finishes.
final class IsolatedDefaults {
  let suiteName: String
  let defaults: UserDefaults

  init(_ name: String = #function) {
    suiteName = "IsolatedDefaults.\(name).\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)!
  }

  func remove() {
    defaults.removePersistentDomain(forName: suiteName)
  }
}
