//
//  AppStoreUpdateCheckTests.swift
//
//
//  Created by Jordan Morgan on 26/08/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("App Store update check")
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
