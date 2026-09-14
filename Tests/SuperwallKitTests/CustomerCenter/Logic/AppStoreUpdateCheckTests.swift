//
//  AppStoreUpdateCheckTests.swift
//
//
//  Created by Jordan Morgan on 26/08/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

/// `.serialized` because `StubURLProtocol` below is the only way to stand in for the network here,
/// and `URLSession` instantiates protocol classes itself — so its configuration and its record of
/// what was requested have to be static. Run in parallel, the cases overwrite each other's stub
/// responses and share a request count, which is how they passed locally and failed on CI.
@Suite("App Store update check", .serialized)
@MainActor
struct AppStoreUpdateCheckTests {
  private func makeViewModel(
    installed: String,
    isSandbox: Bool = false,
    configuredLatest: String? = nil,
    checksAppStore: Bool = true,
    shouldWarn: Bool = true,
    appStoreVersion: String? = nil
  ) -> (CustomerCenterViewModel, AppStoreVersionProviderMock) {
    let provider = AppStoreVersionProviderMock(version: appStoreVersion)
    let (deps, _, _) = CustomerCenterDependencies.mock(
      info: CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: []),
      environment: EnvironmentMock(appVersion: installed, isSandbox: isSandbox),
      appStoreVersion: provider
    )
    let configuration = CustomerCenterConfiguration.default
    configuration.support.latestAppVersion = configuredLatest
    configuration.support.checksAppStoreForUpdates = checksAppStore
    configuration.support.shouldWarnToUpdate = shouldWarn
    let viewModel = CustomerCenterViewModel(
      configuration: configuration,
      dependencies: deps,
      strings: .english
    )
    return (viewModel, provider)
  }

  // MARK: - The lookup drives the banner

  @available(iOS 15.0, *)
  @Test("shows the banner when the App Store is ahead of the installed build")
  func showsBannerWhenStoreIsAhead() async {
    let (viewModel, provider) = makeViewModel(installed: "1.4.0", appStoreVersion: "1.5.0")
    await viewModel.load()
    #expect(provider.callCount == 1)
    #expect(viewModel.showsUpdateBanner)
  }

  @available(iOS 15.0, *)
  @Test("stays hidden when the installed build matches the App Store")
  func hiddenWhenUpToDate() async {
    let (viewModel, _) = makeViewModel(installed: "1.5.0", appStoreVersion: "1.5.0")
    await viewModel.load()
    #expect(!viewModel.showsUpdateBanner)
  }

  /// The case that rules out an `installed != latest` comparison: a build ahead of the store is
  /// normal for testers, and telling them to "update" would send them backwards.
  @available(iOS 15.0, *)
  @Test("stays hidden when the installed build is ahead of the App Store")
  func hiddenWhenAheadOfStore() async {
    let (viewModel, _) = makeViewModel(installed: "2.0.0", appStoreVersion: "1.9.3")
    await viewModel.load()
    #expect(!viewModel.showsUpdateBanner)
  }

  /// Calendar versioning is still a monotonically increasing numeric tuple, so ordered comparison
  /// works on it exactly as it does on semantic versions.
  @available(iOS 15.0, *)
  @Test("orders calendar versions correctly", arguments: [
    ("2026.2.9", "2026.3.1", true),
    ("2026.3.1", "2026.2.9", false),
    ("2025.12.0", "2026.1.0", true)
  ])
  func ordersCalendarVersions(installed: String, store: String, expected: Bool) async {
    let (viewModel, _) = makeViewModel(installed: installed, appStoreVersion: store)
    await viewModel.load()
    #expect(viewModel.showsUpdateBanner == expected)
  }

  // MARK: - When the lookup must not run

  @available(iOS 15.0, *)
  @Test("never looks the version up on TestFlight, sandbox or simulator builds")
  func skipsLookupInSandbox() async {
    let (viewModel, provider) = makeViewModel(
      installed: "1.4.0",
      isSandbox: true,
      appStoreVersion: "1.5.0"
    )
    await viewModel.load()
    #expect(provider.callCount == 0, "a sandbox build must not reach the network")
    #expect(!viewModel.showsUpdateBanner)
  }

  @available(iOS 15.0, *)
  @Test("a configured version wins and suppresses the lookup")
  func configuredVersionWins() async {
    let (viewModel, provider) = makeViewModel(
      installed: "1.4.0",
      configuredLatest: "1.4.0",
      appStoreVersion: "9.9.9"
    )
    await viewModel.load()
    #expect(provider.callCount == 0)
    #expect(!viewModel.showsUpdateBanner, "the configured version says we're current")
  }

  @available(iOS 15.0, *)
  @Test("opting out skips the lookup")
  func optOutSkipsLookup() async {
    let (viewModel, provider) = makeViewModel(
      installed: "1.4.0",
      checksAppStore: false,
      appStoreVersion: "1.5.0"
    )
    await viewModel.load()
    #expect(provider.callCount == 0)
    #expect(!viewModel.showsUpdateBanner)
  }

  @available(iOS 15.0, *)
  @Test("shouldWarnToUpdate off skips the lookup entirely")
  func warningOffSkipsLookup() async {
    let (viewModel, provider) = makeViewModel(
      installed: "1.4.0",
      shouldWarn: false,
      appStoreVersion: "1.5.0"
    )
    await viewModel.load()
    #expect(provider.callCount == 0)
    #expect(!viewModel.showsUpdateBanner)
  }

  @available(iOS 15.0, *)
  @Test("a failed lookup hides the banner rather than guessing")
  func failedLookupHidesBanner() async {
    let (viewModel, provider) = makeViewModel(installed: "1.4.0", appStoreVersion: nil)
    await viewModel.load()
    #expect(provider.callCount == 1)
    #expect(!viewModel.showsUpdateBanner)
  }

  @available(iOS 15.0, *)
  @Test("the lookup runs once per presentation, not once per reload")
  func lookupIsNotRepeated() async {
    let (viewModel, provider) = makeViewModel(installed: "1.4.0", appStoreVersion: "1.5.0")
    await viewModel.load()
    await viewModel.load()
    #expect(provider.callCount == 1)
  }

  // MARK: - Response parsing

  @Test("reads the version out of a lookup response")
  func parsesLookupResponse() throws {
    let json = #"{"resultCount":1,"results":[{"version":"3.2.1","trackName":"Acme"}]}"#
    #expect(AppStoreVersionLookup.parseVersion(from: Data(json.utf8)) == "3.2.1")
  }

  @Test("treats an empty result set as no answer", arguments: [
    #"{"resultCount":0,"results":[]}"#,
    #"{"results":[{"trackName":"Acme"}]}"#,
    #"{"results":[{"version":""}]}"#,
    "not json at all"
  ])
  func parsesUnusableResponses(json: String) {
    #expect(AppStoreVersionLookup.parseVersion(from: Data(json.utf8)) == nil)
  }


  // MARK: - The lookup itself

  /// Everything above this point stops at `parseVersion`, so the network round trip, the 24h
  /// cache and the region query item all shipped unexercised — despite `defaults`, `session` and
  /// `now` existing on the initializer as seams for exactly this. A `URLProtocol` stub and a
  /// throwaway suite of defaults cover them without touching the network.
  private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var requestedURLs: [URL] = []

    static func reset(status: Int = 200, json: String = #"{"results":[{"version":"3.2.1"}]}"#) {
      self.status = status
      self.body = Data(json.utf8)
      self.requestedURLs = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
      if let url = request.url {
        Self.requestedURLs.append(url)
      }
      let response = HTTPURLResponse(
        url: request.url ?? URL(fileURLWithPath: "/"),
        statusCode: Self.status,
        httpVersion: nil,
        headerFields: nil
      )
      // swiftlint:disable:next force_unwrapping
      client?.urlProtocol(self, didReceive: response!, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: Self.body)
      client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
  }

  private func makeStubbedSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
  }

  private func makeDefaults() throws -> UserDefaults {
    let name = "customer-center-tests-\(UUID().uuidString)"
    return try #require(UserDefaults(suiteName: name))
  }

  @Test("scopes the lookup to the bundle id and region")
  func lookupSendsBundleIdAndRegion() async throws {
    StubURLProtocol.reset()
    let lookup = AppStoreVersionLookup(
      bundleId: "com.acme.app",
      regionCode: "GB",
      defaults: try makeDefaults(),
      session: makeStubbedSession()
    )

    #expect(await lookup.latestAppStoreVersion() == "3.2.1")

    let url = try #require(StubURLProtocol.requestedURLs.first)
    let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    #expect(items.contains(URLQueryItem(name: "bundleId", value: "com.acme.app")))
    #expect(items.contains(URLQueryItem(name: "country", value: "GB")))
  }

  /// A device with no region set must still get a lookup, rather than one scoped to an empty
  /// country the endpoint would reject.
  @Test("omits the region when there isn't one", arguments: [nil, ""])
  func lookupOmitsAnEmptyRegion(region: String?) async throws {
    StubURLProtocol.reset()
    let lookup = AppStoreVersionLookup(
      bundleId: "com.acme.app",
      regionCode: region,
      defaults: try makeDefaults(),
      session: makeStubbedSession()
    )

    _ = await lookup.latestAppStoreVersion()

    let url = try #require(StubURLProtocol.requestedURLs.first)
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(!items.contains { $0.name == "country" })
  }

  @Test("a non-2xx response is not an answer", arguments: [404, 429, 500])
  func lookupIgnoresErrorResponses(status: Int) async throws {
    StubURLProtocol.reset(status: status)
    let lookup = AppStoreVersionLookup(
      bundleId: "com.acme.app",
      defaults: try makeDefaults(),
      session: makeStubbedSession()
    )

    #expect(await lookup.latestAppStoreVersion() == nil)
  }

  @Test("a second check inside 24 hours is answered from the cache")
  func lookupCachesWithinTheDay() async throws {
    StubURLProtocol.reset()
    let defaults = try makeDefaults()
    let session = makeStubbedSession()
    var clock = Date(timeIntervalSince1970: 1_000_000)
    let lookup = AppStoreVersionLookup(
      bundleId: "com.acme.app",
      defaults: defaults,
      session: session,
      now: { clock }
    )

    #expect(await lookup.latestAppStoreVersion() == "3.2.1")
    #expect(StubURLProtocol.requestedURLs.count == 1)

    // A day minus a minute later, and the answer on the wire has changed. The cache must win.
    clock = clock.addingTimeInterval(AppStoreVersionLookup.cacheDuration - 60)
    StubURLProtocol.body = Data(#"{"results":[{"version":"9.9.9"}]}"#.utf8)
    #expect(await lookup.latestAppStoreVersion() == "3.2.1", "still inside the cache window")
    #expect(StubURLProtocol.requestedURLs.count == 1, "and no second request was made")
  }

  /// The cache holds one answer, and the answer is region-specific: a version that exists in one
  /// store may not exist in another. Keying on time alone served the previous region's answer for
  /// the rest of the day — precisely when it is most likely to be wrong.
  @Test("changing region is a cache miss")
  func lookupDoesNotServeAnotherRegionsAnswer() async throws {
    StubURLProtocol.reset()
    let defaults = try makeDefaults()
    let session = makeStubbedSession()
    let clock = Date(timeIntervalSince1970: 1_000_000)

    let inGB = AppStoreVersionLookup(
      bundleId: "com.acme.app",
      regionCode: "GB",
      defaults: defaults,
      session: session,
      now: { clock }
    )
    #expect(await inGB.latestAppStoreVersion() == "3.2.1")

    StubURLProtocol.body = Data(#"{"results":[{"version":"1.0.0"}]}"#.utf8)
    let inJP = AppStoreVersionLookup(
      bundleId: "com.acme.app",
      regionCode: "JP",
      defaults: defaults,
      session: session,
      now: { clock }
    )

    #expect(await inJP.latestAppStoreVersion() == "1.0.0", "same second, different store")
    #expect(StubURLProtocol.requestedURLs.count == 2)
  }

  @Test("the cache expires after 24 hours")
  func lookupRefetchesAfterTheDay() async throws {
    StubURLProtocol.reset()
    let defaults = try makeDefaults()
    let session = makeStubbedSession()
    var clock = Date(timeIntervalSince1970: 1_000_000)
    let lookup = AppStoreVersionLookup(
      bundleId: "com.acme.app",
      defaults: defaults,
      session: session,
      now: { clock }
    )

    _ = await lookup.latestAppStoreVersion()
    clock = clock.addingTimeInterval(AppStoreVersionLookup.cacheDuration + 1)
    StubURLProtocol.body = Data(#"{"results":[{"version":"9.9.9"}]}"#.utf8)

    #expect(await lookup.latestAppStoreVersion() == "9.9.9")
    #expect(StubURLProtocol.requestedURLs.count == 2)
  }

  // MARK: - Configuration round trip

  @Test("configuration written before the flag existed still decodes")
  func decodesLegacyConfiguration() throws {
    let json = #"{"email":"help@acme.com","shouldWarnToUpdate":true}"#
    let support = try JSONDecoder().decode(
      CustomerCenterConfiguration.Support.self,
      from: Data(json.utf8)
    )
    #expect(support.email == "help@acme.com")
    #expect(support.checksAppStoreForUpdates, "absent flag should default to on")
  }
}
