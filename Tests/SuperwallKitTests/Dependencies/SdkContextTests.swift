//
//  SdkContextTests.swift
//  SuperwallKit
//
//  Created by Superwall on 16/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

/// Answers for the rest of the SDK, and counts what's asked of it.
private final class FakeSdkContext: SdkContext, @unchecked Sendable {
  private let lock = NSLock()
  private var _assignmentFetches = 0
  var config: Config?
  var isUserIdSeedEnabledInOptions = false

  var assignmentFetches: Int {
    lock.lock()
    defer { lock.unlock() }
    return _assignmentFetches
  }

  func awaitConfig() async -> Config? {
    return config
  }

  func fetchAssignments() async {
    lock.lock()
    _assignmentFetches += 1
    lock.unlock()
  }
}

@Suite("IdentityManager reaches the rest of the SDK through SdkContext")
struct SdkContextTests {
  private func makeIdentityManager(
    in dependencyContainer: DependencyContainer,
    sdkContext: SdkContext
  ) -> IdentityManager {
    return IdentityManager(
      deviceHelper: dependencyContainer.deviceHelper,
      storage: dependencyContainer.storage,
      sdkContext: sdkContext,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      track: { _ in }
    )
  }

  @Test("the user id seed comes from the config the context returns")
  func userIdSeedUsesContextConfig() async {
    let dependencyContainer = DependencyContainer()
    let sdkContext = FakeSdkContext()
    var config = Config.stub()
    config.featureFlags.enableUserIdSeed = true
    sdkContext.config = config
    let identityManager = makeIdentityManager(in: dependencyContainer, sdkContext: sdkContext)

    let seed = await identityManager.userIdSeed(for: "user")

    #expect(seed == "user".sha256MappedToRange().map { .derived($0) })
  }

  @Test("the user id seed comes from the options without waiting for the config")
  func userIdSeedUsesContextOptions() async {
    let dependencyContainer = DependencyContainer()
    let sdkContext = FakeSdkContext()
    sdkContext.isUserIdSeedEnabledInOptions = true
    let identityManager = makeIdentityManager(in: dependencyContainer, sdkContext: sdkContext)

    let expected = "user".sha256MappedToRange()
    #expect(expected != nil)
    #expect(identityManager.userIdSeedFromOptions(for: "user") == expected)
    #expect(await identityManager.userIdSeed(for: "user") == expected.map { .derived($0) })
  }

  @Test("the options give no user id seed when they leave it off")
  func noSeedFromOptionsWhenOff() {
    let dependencyContainer = DependencyContainer()
    let sdkContext = FakeSdkContext()
    let identityManager = makeIdentityManager(in: dependencyContainer, sdkContext: sdkContext)

    #expect(identityManager.userIdSeedFromOptions(for: "user") == nil)
  }

  @Test("the user keeps their seed when the config turns user id seeds off")
  func noSeedWhenFlagOff() async {
    let dependencyContainer = DependencyContainer()
    let sdkContext = FakeSdkContext()
    var config = Config.stub()
    config.featureFlags.enableUserIdSeed = false
    sdkContext.config = config
    let identityManager = makeIdentityManager(in: dependencyContainer, sdkContext: sdkContext)

    #expect(await identityManager.userIdSeed(for: "user") == .off)
  }

  @Test("the user id seed isn't known when the config never arrives")
  func noSeedWithoutConfig() async {
    let dependencyContainer = DependencyContainer()
    let sdkContext = FakeSdkContext()
    let identityManager = makeIdentityManager(in: dependencyContainer, sdkContext: sdkContext)

    #expect(await identityManager.userIdSeed(for: "user") == .unknown)
  }

  @Test("fetching assignments goes to the context")
  func fetchAssignmentsGoesToContext() async {
    let dependencyContainer = DependencyContainer()
    let sdkContext = FakeSdkContext()
    let identityManager = makeIdentityManager(in: dependencyContainer, sdkContext: sdkContext)

    await identityManager.fetchAssignments()

    #expect(sdkContext.assignmentFetches == 1)
  }
}
