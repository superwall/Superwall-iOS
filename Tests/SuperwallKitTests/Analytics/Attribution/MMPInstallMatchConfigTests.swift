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

  /// Starts matches the way `Superwall` does, skipping them while the app is
  /// opted out. A match with no `run` opts the app out while it's under way,
  /// as if during its IP lookup, so the request stops.
  private func startMatches(
    on dependencyContainer: DependencyContainer,
    counting started: Counter,
    run: ((Int) async -> Void)? = nil
  ) {
    let manager = dependencyContainer.mmpAttributionManager!
    manager.matchInstallOnceEnabled {
      if dependencyContainer.configManager.options.eventTrackingBehavior == .none {
        return nil
      }
      started.count += 1
      let attempt = started.count
      return Task {
        if let run {
          await run(attempt)
          return
        }
        dependencyContainer.configManager.options.eventTrackingBehavior = .none
        _ = await manager.matchInstall(
          idfa: nil,
          advertiserTrackingEnabled: false,
          applicationTrackingEnabled: true
        )
      }
    }
  }

  private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<100 where !condition() {
      try? await Task.sleep(nanoseconds: 20_000_000)
    }
  }

  @Test
  func matchStoppedByAnOptOutStartsAgainOnOptIn() async {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.mmpAttributionManager!
    let started = Counter()
    startMatches(on: dependencyContainer, counting: started)
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: true)))
    #expect(started.count == 1)

    // Let the stopped match finish while the app is still opted out.
    try? await Task.sleep(nanoseconds: 300_000_000)
    #expect(started.count == 1)

    dependencyContainer.configManager.options.eventTrackingBehavior = .all
    manager.startMatchIfEnabled()
    #expect(started.count == 2)
  }

  @Test
  func matchStartsAgainWhenTheAppOptsInBeforeTheStoppedMatchFinishes() async {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.mmpAttributionManager!
    let started = Counter()
    startMatches(on: dependencyContainer, counting: started) { attempt in
      if attempt > 1 {
        return
      }
      dependencyContainer.configManager.options.eventTrackingBehavior = .none
      _ = await manager.matchInstall(
        idfa: nil,
        advertiserTrackingEnabled: false,
        applicationTrackingEnabled: true
      )
      // The app opts back in while this match is still finishing, so its
      // opt-in finds the match running and can't start it.
      dependencyContainer.configManager.options.eventTrackingBehavior = .all
      manager.startMatchIfEnabled()
    }
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: true)))

    await waitUntil { started.count == 2 }
    #expect(started.count == 2)
  }

  @Test
  func paywallWaitsForAMatchRestartedAfterAnOptOut() async {
    let dependencyContainer = DependencyContainer()
    let manager = dependencyContainer.mmpAttributionManager!
    let started = Counter()
    let finished = Counter()
    startMatches(on: dependencyContainer, counting: started) { attempt in
      if attempt == 1 {
        dependencyContainer.configManager.options.eventTrackingBehavior = .none
        _ = await manager.matchInstall(
          idfa: nil,
          advertiserTrackingEnabled: false,
          applicationTrackingEnabled: true
        )
        // The app opts back in while this match is still finishing.
        dependencyContainer.configManager.options.eventTrackingBehavior = .all
        return
      }
      // The restarted match finishes a moment later.
      try? await Task.sleep(nanoseconds: 300_000_000)
      finished.count += 1
    }
    dependencyContainer.configManager.configState.send(.retrieved(makeConfig(mmpEnabled: true)))

    await waitUntil { started.count == 2 }
    #expect(started.count == 2)

    await manager.waitForPendingMatch(
      ifUsedBy: makeTrigger(expression: "user.acquisition_source == \"tiktok\""),
      timeout: 10
    )
    #expect(finished.count == 1)
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
