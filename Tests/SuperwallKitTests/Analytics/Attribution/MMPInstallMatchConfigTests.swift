//
//  MMPInstallMatchConfigTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 30/09/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite
struct MMPInstallMatchConfigTests {
  private final class Counter {
    var count = 0
  }

  private func makeConfig(mmpEnabled: Bool?) -> Config {
    var config = Config.stub()
    config.attribution = Attribution(
      appleSearchAds: AppleSearchAds(enabled: true),
      mmp: mmpEnabled.map { MMPAttribution(enabled: $0) }
    )
    return config
  }

  @Test
  func waitsForConfigToEnableTheMMP() {
    let dependencyContainer = DependencyContainer()
    let counter = Counter()

    dependencyContainer.mmpAttributionManager.matchInstallOnceEnabled {
      counter.count += 1
    }
    #expect(counter.count == 0)

    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: true)))
    #expect(counter.count == 1)
  }

  @Test
  func neverMatchesWhenConfigDoesNotEnableTheMMP() {
    let dependencyContainer = DependencyContainer()
    let counter = Counter()

    dependencyContainer.mmpAttributionManager.matchInstallOnceEnabled {
      counter.count += 1
    }
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: nil)))
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: false)))

    #expect(counter.count == 0)
  }

  @Test
  func matchesStraightAwayWhenConfigIsAlreadyLoaded() {
    let dependencyContainer = DependencyContainer()
    let counter = Counter()
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: true)))

    dependencyContainer.mmpAttributionManager.matchInstallOnceEnabled {
      counter.count += 1
    }

    #expect(counter.count == 1)
  }

  @Test
  func matchesOnlyOnceWhenConfigRefreshes() {
    let dependencyContainer = DependencyContainer()
    let counter = Counter()

    dependencyContainer.mmpAttributionManager.matchInstallOnceEnabled {
      counter.count += 1
    }
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: true)))
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: false)))
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: true)))

    #expect(counter.count == 1)
  }
}
