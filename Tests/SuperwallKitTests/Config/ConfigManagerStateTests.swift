//
//  ConfigManagerStateTests.swift
//  SuperwallKit
//
//  Created by Superwall on 03/11/2026.
//
// swiftlint:disable all

import Combine
import Foundation
import Testing
@testable import SuperwallKit

@Suite("ConfigUpdate reducers")
struct ConfigUpdateTests {
  @Test("retrying sets the state and the retry count")
  func retrying() {
    let state = ConfigUpdate.retrying(attempt: 2).reduce(ConfigManagerState())
    #expect(state.configState == .retrying)
    #expect(state.retryCount == 2)
  }

  @Test("retryCount changes only the count")
  func retryCount() {
    var start = ConfigManagerState()
    start.configState = .retrieved(.stub())
    let state = ConfigUpdate.retryCount(3).reduce(start)
    #expect(state.retryCount == 3)
    #expect(state.config != nil)
  }

  @Test("retrieved sets the config")
  func retrieved() {
    let config = Config.stub().setting(\.buildId, to: "build")
    let state = ConfigUpdate.retrieved(config).reduce(ConfigManagerState())
    #expect(state.config?.buildId == "build")
  }

  @Test("failed records the error and drops the config")
  func failed() {
    var start = ConfigManagerState()
    start.configState = .retrieved(.stub())
    let state = ConfigUpdate.failed(TestError("boom")).reduce(start)
    #expect(state.configState == .failed)
    #expect(state.config == nil)
    #expect((state.failure as? TestError)?.message == "boom")
  }

  @Test("triggers and the purchases load leave the config state alone")
  func sideFields() {
    var start = ConfigManagerState()
    start.configState = .retrieving
    let trigger = Trigger.stub().setting(\.placementName, to: "placement")
    let withTriggers = ConfigUpdate.triggers(["placement": trigger]).reduce(start)
    #expect(withTriggers.triggersByPlacementName["placement"]?.placementName == "placement")
    #expect(withTriggers.configState == .retrieving)

    let load = Task<Void, Never> {}
    let withLoad = ConfigUpdate.initialPurchasesLoad(load).reduce(start)
    #expect(withLoad.initialPurchasesLoad != nil)
    #expect(withLoad.configState == .retrieving)
  }

  @Test("Only config state changes are published")
  func publications() {
    #expect(ConfigUpdate.retryCount(1).publication == nil)
    #expect(ConfigUpdate.triggers([:]).publication == nil)
    if case .value(.retrying)? = ConfigUpdate.retrying(attempt: 1).publication {} else {
      Issue.record("retrying should publish .retrying")
    }
    if case .failure? = ConfigUpdate.failed(TestError("e")).publication {} else {
      Issue.record("failed should publish a failure")
    }
  }
}

@Suite("ConfigManager store")
struct ConfigManagerStoreTests {
  /// The container owns what the config manager holds unowned references to,
  /// so tests keep it alive until they finish.
  private func makeConfigManager() -> (ConfigManager, NetworkMock, DependencyContainer) {
    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(
      options: SuperwallOptions(),
      factory: dependencyContainer
    )
    let configManager = ConfigManager(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: StorageMock(),
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    return (configManager, network, dependencyContainer)
  }

  @Test("configState mirrors every config state change, in order")
  func configStateMirrorsTheStore() {
    let (configManager, _, container) = makeConfigManager()
    defer { withExtendedLifetime(container) {} }
    var received: [ConfigState] = []
    let cancellable = configManager.configState.sink(
      receiveCompletion: { _ in },
      receiveValue: { received.append($0) }
    )
    defer { cancellable.cancel() }

    let config = Config.stub().setting(\.buildId, to: "build")
    configManager.store.update(ConfigUpdate.retrying(attempt: 1))
    configManager.store.update(ConfigUpdate.triggers([:]))
    configManager.store.update(ConfigUpdate.retrieved(config))

    #expect(received == [.retrieving, .retrying, .retrieved(config)])
    #expect(configManager.config?.buildId == "build")
    #expect(configManager.configRetryCount == 1)
  }

  @Test("A failure completes configState with the error")
  func failureCompletesConfigState() async {
    let (configManager, _, container) = makeConfigManager()
    defer { withExtendedLifetime(container) {} }
    configManager.store.update(ConfigUpdate.failed(TestError("offline")))

    await #expect(throws: TestError.self) {
      _ = try await configManager.configState
        .compactMap { $0.getConfig() }
        .throwableAsync()
    }
  }

  @Test("Refreshing without a config does nothing")
  func refreshWithoutConfig() async {
    let (configManager, network, container) = makeConfigManager()
    defer { withExtendedLifetime(container) {} }
    await configManager.refreshConfiguration(isUserInitiated: true)
    #expect(network.getConfigCalled == false)
  }

  @Test("Refreshes called together run one after the other")
  func refreshesAreSerialized() async {
    let (configManager, network, container) = makeConfigManager()
    defer { withExtendedLifetime(container) {} }
    configManager.store.update(ConfigUpdate.retrieved(.stub().setting(\.buildId, to: "old")))
    network.configReturnValue = .success(.stub().setting(\.buildId, to: "new"))

    async let first: Void = configManager.refreshConfiguration(isUserInitiated: true)
    async let second: Void = configManager.refreshConfiguration(isUserInitiated: true)
    _ = await (first, second)

    #expect(configManager.config?.buildId == "new")
    // Nothing is left running once both have returned.
    await configManager.store.flush()
    #expect(configManager.config?.buildId == "new")
  }
}
