//
//  AppVersionComparator.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation

/// Compares marketing version strings on up to three leading numeric components.
enum AppVersionComparator {
  /// Returns `true` only when both strings parse and `installed` < `latest`.
  static func isInstalledVersion(_ installed: String?, olderThan latest: String?) -> Bool {
    guard
      let installed = parse(installed),
      let latest = parse(latest)
    else {
      return false
    }
    return installed.lexicographicallyPrecedes(latest)
  }

  /// Parses "1.2.3", "1.2", "1" → [major, minor, patch]; returns nil if the first component isn't numeric.
  static func parse(_ version: String?) -> [Int]? {
    guard let version else { return nil }
    let parts = version.split(separator: ".", omittingEmptySubsequences: false).prefix(3).map { Int($0) }
    guard let first = parts.first, first != nil else { return nil }
    var result = parts.map { $0 ?? 0 }
    while result.count < 3 { result.append(0) }
    return result
  }
}
