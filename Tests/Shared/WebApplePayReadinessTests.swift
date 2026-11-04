//
//  WebApplePayReadinessTests.swift
//  SuperwallKit
//
//  Created by Jake Mor on 04/11/2026.
//
// swiftlint:disable all

@testable import SuperwallKit
import Foundation
import Testing
import WebKit

@Suite
struct WebApplePayReadinessTests {
  private let origin = URL(string: "https://magicedit.superwall.app")!

  /// Stands in for the web view, answering with whatever the test sets.
  @MainActor
  final class FakeProbe {
    var outcome: WebApplePayProbe.Outcome
    var delay: TimeInterval
    private(set) var origins: [URL] = []

    init(_ readiness: WebApplePayReadiness, delay: TimeInterval = 0) {
      self.outcome = .init(readiness: readiness, duration: 0.1, failureReason: nil)
      self.delay = delay
    }

    func measure(_ origin: URL) async -> WebApplePayProbe.Outcome {
      origins.append(origin)
      if delay > 0 {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
      return outcome
    }
  }

  /// Storage that outlives one tracker, as the cache outlives a launch.
  final class FakeStore: @unchecked Sendable {
    var measurement: WebApplePayMeasurement?
    var saves = 0
  }

  private func makeTracker(
    store: FakeStore = FakeStore(),
    probe: FakeProbe
  ) -> WebApplePayReadinessTracker {
    return WebApplePayReadinessTracker(
      load: { store.measurement },
      save: { store.measurement = $0; store.saves += 1 },
      measure: { await probe.measure($0) }
    )
  }

  private func config(web2app: Config.Web2AppConfig?, expression: String? = nil) -> Config {
    var rule = TriggerRule.stub()
    rule.expression = expression
    return Config.stub()
      .setting(\.web2appConfig, to: web2app)
      .setting(\.triggers, to: [Trigger(placementName: "app_launch", audiences: [rule])])
  }

  // MARK: - Values

  @Test
  func reportsReadyNotReadyAndUnknownWithItsReason() {
    #expect(WebApplePayReadiness.ready.rawValue == "ready")
    #expect(WebApplePayReadiness.notReady.rawValue == "notReady")
    #expect(WebApplePayReadiness.unknown(.timedOut).rawValue == "unknown:timedOut")
    #expect(WebApplePayReadiness(measuredRawValue: "unknown:timedOut") == nil)
  }

  @Test
  func anActiveCardIsReadyAndNoActiveCardIsNotReady() {
    #expect(WebApplePayProbe.result(for: ["activeCard": true]).readiness == .ready)
    #expect(WebApplePayProbe.result(for: ["activeCard": false]).readiness == .notReady)
  }

  @Test
  func aPageThatCannotAnswerIsUnknownRatherThanNotReady() {
    let noAPI = WebApplePayProbe.result(for: ["error": "noApplePaySession"])
    #expect(noAPI.readiness == .unknown(.noApplePayAPI))
    #expect(noAPI.failureReason == "noApplePaySession")
    #expect(WebApplePayProbe.result(for: ["error": "activeCardRejected: x"]).readiness == .unknown(.apiError))
    #expect(WebApplePayProbe.result(for: ["activeCard": "yes"]).failureReason == "malformedResult")
    #expect(WebApplePayProbe.result(for: [:]).readiness == .unknown(.apiError))
  }

  // MARK: - Checkout origin

  @Test
  func decodesTheWebAppDomainFromConfig() throws {
    let json = """
    {
      "url_schema": "magicedit",
      "entitlements_max_age_ms": 86400000,
      "restore_access_url": "https://magicedit.superwall.app/manage",
      "domain_base_url": "https://magicedit.superwall.app"
    }
    """
    let web2app = try JSONDecoder.fromSnakeCase.decode(Config.Web2AppConfig.self, from: Data(json.utf8))
    #expect(web2app.domainBaseURL == origin)
  }

  @Test
  func probesTheWebAppDomain() {
    let web2app = Config.Web2AppConfig(
      entitlementsMaxAge: 60,
      restoreAccessURL: URL(string: "https://other.superwall.app/manage")!,
      domainBaseURL: URL(string: "https://MagicEdit.superwall.app/")!
    )
    let probed = WebApplePayReadinessTracker.checkoutOrigin(from: config(web2app: web2app))
    #expect(probed == origin)
  }

  @Test
  func fallsBackToTheRestorePagesOrigin() {
    let web2app = Config.Web2AppConfig(
      entitlementsMaxAge: 60,
      restoreAccessURL: URL(string: "https://magicedit.superwall.app/manage?x=1")!
    )
    #expect(WebApplePayReadinessTracker.checkoutOrigin(from: config(web2app: web2app)) == origin)
  }

  @Test
  func probesNothingWithoutAnHttpsWebCheckout() {
    #expect(WebApplePayReadinessTracker.checkoutOrigin(from: config(web2app: nil)) == nil)
    let insecure = Config.Web2AppConfig(
      entitlementsMaxAge: 60,
      restoreAccessURL: URL(string: "http://magicedit.superwall.app/manage")!
    )
    #expect(WebApplePayReadinessTracker.checkoutOrigin(from: config(web2app: insecure)) == nil)
  }

  @Test
  func onlyWaitsWhenAnAudienceUsesTheAttribute() {
    let web2app = Config.Web2AppConfig(entitlementsMaxAge: 60, restoreAccessURL: origin)
    #expect(DeviceHelper.audiencesUseWebApplePayReadiness(
      in: config(web2app: web2app, expression: "device.webApplePayReadiness == \"notReady\"")
    ))
    #expect(!DeviceHelper.audiencesUseWebApplePayReadiness(
      in: config(web2app: web2app, expression: "device.isApplePayAvailable == true")
    ))
  }

  // MARK: - Tracker

  @Test @MainActor
  func reportsWhyThereIsNothingToMeasure() async {
    let tracker = makeTracker(probe: FakeProbe(.ready))
    #expect(await tracker.readiness(at: origin, isEnabled: false) == .unknown(.disabled))
    #expect(await tracker.readiness(at: nil, isEnabled: true) == .unknown(.noCheckoutDomain))
    #expect(await tracker.readiness(at: origin, isEnabled: true) == .unknown(.notMeasured))
  }

  @Test @MainActor
  func aMeasuredAnswerIsServedAtOnceOnTheNextLaunch() async {
    let store = FakeStore()
    let firstLaunch = makeTracker(store: store, probe: FakeProbe(.notReady))
    await firstLaunch.refreshIfNeeded(at: origin).value
    #expect(await firstLaunch.readiness(at: origin, isEnabled: true) == .notReady)

    let nextLaunch = makeTracker(store: store, probe: FakeProbe(.ready, delay: 10))
    #expect(await nextLaunch.readiness(at: origin, isEnabled: true) == .notReady)
  }

  @Test @MainActor
  func anUnknownAnswerNeverReplacesAMeasuredOne() async {
    let store = FakeStore()
    await makeTracker(store: store, probe: FakeProbe(.ready)).refreshIfNeeded(at: origin).value

    let nextLaunch = makeTracker(store: store, probe: FakeProbe(.unknown(.timedOut)))
    await nextLaunch.refreshIfNeeded(at: origin).value

    #expect(await nextLaunch.readiness(at: origin, isEnabled: true) == .ready)
    #expect(store.measurement?.readiness == "ready")
    #expect(store.saves == 1)
  }

  @Test @MainActor
  func anUnknownAnswerIsReportedWhenNothingWasEverMeasured() async {
    let tracker = makeTracker(probe: FakeProbe(.unknown(.noApplePayAPI)))
    await tracker.refreshIfNeeded(at: origin).value
    #expect(await tracker.readiness(at: origin, isEnabled: true) == .unknown(.noApplePayAPI))
  }

  @Test @MainActor
  func anAnswerFromAnotherOriginIsIgnored() async {
    let store = FakeStore()
    store.measurement = .init(origin: "https://old.superwall.app", readiness: "notReady", measuredAt: Date())
    let tracker = makeTracker(store: store, probe: FakeProbe(.ready))
    #expect(await tracker.readiness(at: origin, isEnabled: true) == .unknown(.notMeasured))
  }

  @Test @MainActor
  func onlyOneProbeRunsPerLaunch() async {
    let probe = FakeProbe(.ready)
    let tracker = makeTracker(probe: probe)
    await tracker.refreshIfNeeded(at: origin).value
    await tracker.refreshIfNeeded(at: origin).value
    await tracker.waitForFirstMeasurement(at: origin)
    #expect(probe.origins == [origin])
  }

  @Test @MainActor
  func aFirstLaunchWaitsForTheFirstAnswer() async {
    let tracker = makeTracker(probe: FakeProbe(.notReady, delay: 0.05))
    let startedAt = Date()
    await tracker.waitForFirstMeasurement(at: origin, budget: 5)
    #expect(Date().timeIntervalSince(startedAt) < 2)
    #expect(await tracker.readiness(at: origin, isEnabled: true) == .notReady)
  }

  @Test @MainActor
  func aFirstLaunchGivesUpOnAProbeSlowerThanTheBudget() async {
    let tracker = makeTracker(probe: FakeProbe(.ready, delay: 10))
    let startedAt = Date()
    await tracker.waitForFirstMeasurement(at: origin, budget: 0.1)
    #expect(Date().timeIntervalSince(startedAt) < 2)
    #expect(await tracker.readiness(at: origin, isEnabled: true) == .unknown(.notMeasured))
  }

  @Test @MainActor
  func theBudgetIsSpentOncePerLaunch() async {
    let tracker = makeTracker(probe: FakeProbe(.ready, delay: 10))
    await tracker.waitForFirstMeasurement(at: origin, budget: 0.2)
    let startedAt = Date()
    await tracker.waitForFirstMeasurement(at: origin, budget: 0.2)
    #expect(Date().timeIntervalSince(startedAt) < 0.1)
  }

  @Test @MainActor
  func aLaunchWithAStoredAnswerDoesNotWait() async {
    let store = FakeStore()
    store.measurement = .init(origin: origin.absoluteString, readiness: "ready", measuredAt: Date())
    let tracker = makeTracker(store: store, probe: FakeProbe(.notReady, delay: 10))
    let startedAt = Date()
    await tracker.waitForFirstMeasurement(at: origin, budget: 5)
    #expect(Date().timeIntervalSince(startedAt) < 1)
    #expect(await tracker.readiness(at: origin, isEnabled: true) == .ready)
  }

  // MARK: - Probe

  @Test @MainActor
  func theProbeReportsUnknownWhenItRunsOutOfTime() async {
    let outcome = await WebApplePayProbe(origin: origin, timeout: 0).run()
    #expect(outcome.readiness == .unknown(.timedOut))
    #expect(outcome.failureReason == "timeout")
  }

  @Test @MainActor
  func onlyTheFirstOfTheRacingOutcomesIsKept() async {
    let probe = WebApplePayProbe(origin: origin)
    probe.webViewWebContentProcessDidTerminate(WKWebView())
    probe.finish(readiness: .ready, failureReason: nil)
    let outcome = await probe.run()
    #expect(outcome.readiness == .unknown(.probeFailed))
    #expect(outcome.failureReason == "webContentProcessTerminated")
  }

  @Test @MainActor
  func theProbeAlwaysAnswersWithinItsTimeout() async {
    let outcome = await WebApplePayProbe(origin: origin, timeout: 3).run()
    // The answer depends on the Wallet of the machine running this, so only
    // the contract is checked: it answers, and in bounded time.
    #expect(outcome.duration < 5)
    if outcome.failureReason == "timeout" {
      #expect(outcome.readiness == .unknown(.timedOut))
    }
  }
}
