//
//  AppVersionComparatorTests.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Testing
@testable import SuperwallKit

@Suite("AppVersionComparator")
struct AppVersionComparatorTests {
  @Test(arguments: [
    ("1.0.0" as String?, "1.0.1" as String?, true), ("1.0.0" as String?, "1.1" as String?, true), ("1.9.9" as String?, "2" as String?, true),
    ("2.0.0" as String?, "1.9.9" as String?, false), ("1.2.3" as String?, "1.2.3" as String?, false), ("1.2" as String?, "1.2.0" as String?, false),
    ("1.2.3.4" as String?, "1.2.3" as String?, false), ("1.2.3" as String?, "1.2.3.9" as String?, false),  // 4th component ignored
    ("abc" as String?, "1.0.0" as String?, false), ("1.0.0" as String?, "abc" as String?, false), (nil as String?, "1.0.0" as String?, false), ("1.0.0" as String?, nil as String?, false)
  ])
  func compare(installed: String?, latest: String?, expected: Bool) {
    #expect(AppVersionComparator.isInstalledVersion(installed, olderThan: latest) == expected)
  }
}
