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

  private func makeTrigger(expression: String?) -> Trigger {
    var audience = TriggerRule.stub()
    audience.expression = expression
    return Trigger(placementName: "app_open", audiences: [audience])
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
      return Task {}
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
      return Task {}
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
      return Task {}
    }

    #expect(counter.count == 1)
  }

  @Test
  func matchesOnlyOnceWhenConfigRefreshes() {
    let dependencyContainer = DependencyContainer()
    let counter = Counter()

    dependencyContainer.mmpAttributionManager.matchInstallOnceEnabled {
      counter.count += 1
      return Task {}
    }
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: true)))
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: false)))
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: true)))

    #expect(counter.count == 1)
  }

  @Test
  func startsASkippedMatchWhenTrackingIsTurnedBackOn() {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.mmpAttributionManager!
    let attempts = Counter()
    let started = Counter()
    var isOptedOut = true

    manager.matchInstallOnceEnabled {
      attempts.count += 1
      if isOptedOut {
        return nil
      }
      started.count += 1
      return Task {}
    }
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: true)))
    #expect(attempts.count == 1)
    #expect(started.count == 0)

    isOptedOut = false
    manager.startMatchIfEnabled()
    manager.startMatchIfEnabled()
    #expect(started.count == 1)
    #expect(attempts.count == 2)
  }

  @Test
  func doesNotStartOnOptInWhenTheMMPIsOff() {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.mmpAttributionManager!
    let attempts = Counter()

    manager.matchInstallOnceEnabled {
      attempts.count += 1
      return Task {}
    }
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: false)))
    manager.startMatchIfEnabled()

    #expect(attempts.count == 0)
  }

  // MARK: - Paywalls waiting for the match

  @Test
  func detectsAudiencesThatUseAcquisitionAttributes() {
    #expect(MMPAttributionManager.usesAcquisitionAttributes(
      makeTrigger(expression: "user.acquisition_source == \"tiktok\"")
    ))
    #expect(!MMPAttributionManager.usesAcquisitionAttributes(
      makeTrigger(expression: "user.plan == \"pro\"")
    ))
    #expect(!MMPAttributionManager.usesAcquisitionAttributes(makeTrigger(expression: nil)))
  }

  @Test
  func paywallWaitsForARunningMatch() async {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.mmpAttributionManager!
    let finished = Counter()

    // The match finishes a moment later, so the paywall only sees it finished
    // if it actually waited.
    manager.matchInstallOnceEnabled {
      Task {
        try? await Task.sleep(nanoseconds: 200_000_000)
        finished.count += 1
      }
    }
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: true)))

    let start = Date()
    await manager.waitForPendingMatch(
      ifUsedBy: makeTrigger(expression: "user.acquisition_source == \"tiktok\""),
      timeout: 10
    )
    #expect(finished.count == 1)
    #expect(Date().timeIntervalSince(start) >= 0.2)
  }

  /// A paywall can be requested after the match is marked pending at launch
  /// but before it's set up. It must still wait.
  @Test
  func paywallWaitsForAMatchMarkedPendingBeforeItsSetUp() async {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.mmpAttributionManager!
    let finished = Counter()
    manager.markMatchPending()
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: true)))

    Task {
      try? await Task.sleep(nanoseconds: 100_000_000)
      manager.matchInstallOnceEnabled {
        Task {
          try? await Task.sleep(nanoseconds: 100_000_000)
          finished.count += 1
        }
      }
    }

    let start = Date()
    await manager.waitForPendingMatch(
      ifUsedBy: makeTrigger(expression: "user.acquisition_source == \"tiktok\""),
      timeout: 10
    )
    #expect(finished.count == 1)
    #expect(Date().timeIntervalSince(start) >= 0.2)
  }

  @Test
  func paywallStopsWaitingAfterTheTimeout() async {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.mmpAttributionManager!

    manager.matchInstallOnceEnabled {
      Task {
        try? await Task.sleep(nanoseconds: 60_000_000_000)
      }
    }
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: true)))

    let start = Date()
    await manager.waitForPendingMatch(
      ifUsedBy: makeTrigger(expression: "user.acquisition_source == \"tiktok\""),
      timeout: 0.1
    )
    let elapsed = Date().timeIntervalSince(start)
    #expect(elapsed >= 0.1)
    #expect(elapsed < 5)
  }

  @Test
  func paywallDoesNotWaitWhenItsAudiencesDontNeedTheMatch() async {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.mmpAttributionManager!

    manager.matchInstallOnceEnabled {
      Task {
        try? await Task.sleep(nanoseconds: 60_000_000_000)
      }
    }
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: true)))

    let start = Date()
    await manager.waitForPendingMatch(
      ifUsedBy: makeTrigger(expression: "user.plan == \"pro\""),
      timeout: 30
    )
    #expect(Date().timeIntervalSince(start) < 5)
  }

  @Test
  func paywallDoesNotWaitWhenTheMMPIsOff() async {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.mmpAttributionManager!

    manager.matchInstallOnceEnabled {
      Task {
        try? await Task.sleep(nanoseconds: 60_000_000_000)
      }
    }
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: false)))

    let start = Date()
    await manager.waitForPendingMatch(
      ifUsedBy: makeTrigger(expression: "user.acquisition_source == \"tiktok\""),
      timeout: 30
    )
    #expect(Date().timeIntervalSince(start) < 5)
  }
}
