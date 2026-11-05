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
    #expect(state.configState == .failed(TestError("any")))
    #expect(state.config == nil)
    #expect((state.configState.failure as? TestError)?.message == "boom")
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

  @Test("Only config state updates count as publications")
  func publications() {
    let start = ConfigManagerState()
    #expect(ConfigUpdate.retryCount(1).reduce(start).publications == 0)
    #expect(ConfigUpdate.triggers([:]).reduce(start).publications == 0)
    #expect(ConfigUpdate.initialPurchasesLoad(Task {}).reduce(start).publications == 0)
    #expect(ConfigUpdate.retrying(attempt: 1).reduce(start).publications == 1)
    #expect(ConfigUpdate.retrieved(.stub()).reduce(start).publications == 1)
    #expect(ConfigUpdate.failed(TestError("e")).reduce(start).publications == 1)
    #expect(ConfigUpdate.set(.retrieving).reduce(start).publications == 1)
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

  @Test("An update that leaves the config state as it was is still published")
  func republishesUnchangedState() {
    let (configManager, _, container) = makeConfigManager()
    defer { withExtendedLifetime(container) {} }
    var received: [ConfigState] = []
    let cancellable = configManager.configState.sink(
      receiveCompletion: { _ in },
      receiveValue: { received.append($0) }
    )
    defer { cancellable.cancel() }

    let config = Config.stub()
    configManager.store.update(ConfigUpdate.retrieved(config))
    configManager.store.update(ConfigUpdate.retrieved(config))

    #expect(received == [.retrieving, .retrieved(config), .retrieved(config)])
  }

  @Test("Setting a failed state completes configState, and nothing is sent after")
  func setFailedCompletes() {
    let (configManager, _, container) = makeConfigManager()
    defer { withExtendedLifetime(container) {} }
    var received: [ConfigState] = []
    var completion: Subscribers.Completion<Error>?
    let cancellable = configManager.configState.sink(
      receiveCompletion: { completion = $0 },
      receiveValue: { received.append($0) }
    )
    defer { cancellable.cancel() }

    configManager.store.update(ConfigUpdate.set(.failed(TestError("offline"))))
    configManager.store.update(ConfigUpdate.retrieved(.stub()))

    #expect(received == [.retrieving])
    if case .failure(let error)? = completion {
      #expect((error as? TestError)?.message == "offline")
    } else {
      Issue.record("configState should have completed with the error")
    }
    // The store still changes.
    #expect(configManager.config != nil)
  }

  @Test("Updates from many threads are sent in the order they were applied")
  func concurrentUpdatesArePublishedInOrder() async {
    let (configManager, _, container) = makeConfigManager()
    defer { withExtendedLifetime(container) {} }
    let lock = NSLock()
    var received: [String] = []
    let cancellable = configManager.configState.sink(
      receiveCompletion: { _ in },
      receiveValue: { state in
        lock.lock()
        received.append(state.getConfig()?.buildId ?? "none")
        lock.unlock()
      }
    )
    defer { cancellable.cancel() }

    let configs = (0..<200).map { Config.stub().setting(\.buildId, to: "\($0)") }
    await withTaskGroup(of: Void.self) { group in
      for config in configs {
        group.addTask {
          configManager.store.update(ConfigUpdate.retrieved(config))
        }
      }
    }

    lock.lock()
    let sent = received
    lock.unlock()
    // Every update was sent once, and the last one sent is the store's state.
    #expect(sent.count == configs.count + 1)
    #expect(Set(sent.dropFirst()).count == configs.count)
    #expect(sent.last == configManager.config?.buildId)
    #expect(configManager.configState.value == configManager.store.state.configState)
  }

  @Test("A subscriber that takes a lock can't deadlock with a thread holding it that reads the config")
  func publishingDoesNotHoldTheStoreLock() {
    // As with the MMP manager: its subscriber takes its lock, and it reads
    // `config` while holding that lock.
    let (configManager, _, container) = makeConfigManager()
    defer { withExtendedLifetime(container) {} }
    let otherLock = NSLock()
    let subscriberWaiting = DispatchSemaphore(value: 0)
    let cancellable = configManager.configState
      .dropFirst()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in
          subscriberWaiting.signal()
          otherLock.lock()
          otherLock.unlock()
        }
      )
    defer { cancellable.cancel() }

    otherLock.lock()
    let updated = DispatchSemaphore(value: 0)
    let config = Config.stub().setting(\.buildId, to: "build")
    Thread {
      configManager.store.update(ConfigUpdate.retrieved(config))
      updated.signal()
    }
    .start()
    subscriberWaiting.wait()

    // The publishing thread waits for `otherLock` in the subscriber. If it
    // still held the store's lock, this read would never return.
    let read = DispatchSemaphore(value: 0)
    var buildId: String?
    Thread {
      buildId = configManager.config?.buildId
      read.signal()
    }
    .start()
    let didRead = read.wait(timeout: .now() + 2) == .success
    otherLock.unlock()

    #expect(didRead)
    #expect(buildId == "build")
    #expect(updated.wait(timeout: .now() + 2) == .success)
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

    // The first request is held open until the test releases it. If the
    // refreshes overlapped, the second request would start meanwhile.
    let firstResponse = ResponseGate()
    let requests = RequestCounter()
    network.getConfigHandler = {
      switch requests.next() {
      case 1:
        await firstResponse.wait()
        return .stub().setting(\.buildId, to: "first")
      default:
        return .stub().setting(\.buildId, to: "second")
      }
    }
    let published = PublishedBuildIds()
    let cancellable = configManager.configState.sink(
      receiveCompletion: { _ in },
      receiveValue: { published.append($0.getConfig()?.buildId ?? "none") }
    )
    defer { cancellable.cancel() }

    async let first: Void = configManager.refreshConfiguration(isUserInitiated: true)
    async let second: Void = configManager.refreshConfiguration(isUserInitiated: true)

    for _ in 0..<1_000 where requests.count == 0 {
      try? await Task.sleep(nanoseconds: 1_000_000)
    }
    #expect(requests.count == 1)
    // Give an overlapping second refresh every chance to start.
    try? await Task.sleep(nanoseconds: 100_000_000)
    #expect(requests.count == 1)
    #expect(configManager.config?.buildId == "old")

    await firstResponse.open()
    _ = await (first, second)

    #expect(requests.count == 2)
    // Each refresh's config is published in turn, the first's before the
    // second's.
    let inOrder = published.values.reduce(into: [String]()) { result, value in
      if result.last != value {
        result.append(value)
      }
    }
    #expect(inOrder == ["old", "first", "second"])
    #expect(configManager.config?.buildId == "second")
  }
}

/// Holds a request open until it's opened.
private actor ResponseGate {
  private var isOpen = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func wait() async {
    if isOpen {
      return
    }
    await withCheckedContinuation { waiters.append($0) }
  }

  func open() {
    isOpen = true
    let waiters = self.waiters
    self.waiters = []
    for waiter in waiters {
      waiter.resume()
    }
  }
}

/// Counts requests across threads.
private final class RequestCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var _count = 0

  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return _count
  }

  /// Counts a request and returns its number, from 1.
  func next() -> Int {
    lock.lock()
    defer { lock.unlock() }
    _count += 1
    return _count
  }
}

/// The build ids `configState` sent, from any thread.
private final class PublishedBuildIds: @unchecked Sendable {
  private let lock = NSLock()
  private var _values: [String] = []

  var values: [String] {
    lock.lock()
    defer { lock.unlock() }
    return _values
  }

  func append(_ value: String) {
    lock.lock()
    _values.append(value)
    lock.unlock()
  }
}
