//
//  DependencyContainerInitTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 25/08/2026.
//

import Testing
@testable import SuperwallKit
import Foundation

struct DependencyContainerInitTests {
  /// https://github.com/superwall/Superwall-iOS/issues/504
  ///
  /// `DependencyContainer.init` used to pass `self` to `WebEntitlementRedeemer`,
  /// whose init spawned a task reading `configManager` on a background thread
  /// while init was still assigning stored properties. This loop only signals
  /// under Thread Sanitizer (`-enableThreadSanitizer YES`), where it reproduced
  /// the race on the first iteration; without TSan it's a smoke test.
  @Test("Constructing the container doesn't race against its own init")
  func containerInitHasNoDataRace() {
    for _ in 0..<10 {
      _ = DependencyContainer(apiKey: "pk_test_504")
    }
  }
}
