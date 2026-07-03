//
//  PlacementsQueueTests.swift
//
//
//  Created by Yusuf Tör on 22/06/2026.
//
// swiftlint:disable all

import Testing
import Foundation
@testable import SuperwallKit

@Suite(.serialized)
struct PlacementsQueueTests {
  private let stubJSON = JSON(["event": "test"])

  // MARK: - EventTrackingBehavior.all

  @Test
  func all_allowsUserInitiatedTrack() async throws {
    let setup = makeQueue(behavior: .all)

    await setup.queue.enqueue(
      data: stubJSON,
      from: UserInitiatedPlacement.Track(
        rawName: "test",
        canImplicitlyTriggerPaywall: false,
        isFeatureGatable: false
      )
    )
    await setup.queue.flushInternal()
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(setup.network.sentEvents.count == 1)
  }

  @Test
  func all_allowsTriggerFire() async throws {
    let setup = makeQueue(behavior: .all)

    await setup.queue.enqueue(
      data: stubJSON,
      from: InternalSuperwallEvent.TriggerFire(
        triggerResult: .noAudienceMatch([]),
        triggerName: "test"
      )
    )
    await setup.queue.flushInternal()
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(setup.network.sentEvents.count == 1)
  }

  @Test
  func all_allowsUserAttributes() async throws {
    let setup = makeQueue(behavior: .all)

    await setup.queue.enqueue(
      data: stubJSON,
      from: InternalSuperwallEvent.UserAttributes(appInstalledAtString: "now")
    )
    await setup.queue.flushInternal()
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(setup.network.sentEvents.count == 1)
  }

  @Test
  func all_allowsInternalEvent() async throws {
    let setup = makeQueue(behavior: .all)

    await setup.queue.enqueue(data: stubJSON, from: InternalSuperwallEvent.AppOpen())
    await setup.queue.flushInternal()
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(setup.network.sentEvents.count == 1)
  }

  // MARK: - EventTrackingBehavior.superwallOnly

  @Test
  func superwallOnly_blocksUserInitiatedTrack() async throws {
    let setup = makeQueue(behavior: .superwallOnly)

    await setup.queue.enqueue(
      data: stubJSON,
      from: UserInitiatedPlacement.Track(
        rawName: "test",
        canImplicitlyTriggerPaywall: false,
        isFeatureGatable: false
      )
    )
    await setup.queue.flushInternal()
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(setup.network.sentEvents.isEmpty)
  }

  @Test
  func superwallOnly_blocksTriggerFire() async throws {
    let setup = makeQueue(behavior: .superwallOnly)

    await setup.queue.enqueue(
      data: stubJSON,
      from: InternalSuperwallEvent.TriggerFire(
        triggerResult: .noAudienceMatch([]),
        triggerName: "test"
      )
    )
    await setup.queue.flushInternal()
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(setup.network.sentEvents.isEmpty)
  }

  @Test
  func superwallOnly_blocksUserAttributes() async throws {
    let setup = makeQueue(behavior: .superwallOnly)

    await setup.queue.enqueue(
      data: stubJSON,
      from: InternalSuperwallEvent.UserAttributes(appInstalledAtString: "now")
    )
    await setup.queue.flushInternal()
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(setup.network.sentEvents.isEmpty)
  }

  @Test
  func superwallOnly_allowsInternalEvent() async throws {
    let setup = makeQueue(behavior: .superwallOnly)

    await setup.queue.enqueue(data: stubJSON, from: InternalSuperwallEvent.AppOpen())
    await setup.queue.flushInternal()
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(setup.network.sentEvents.count == 1)
  }

  @Test
  func superwallOnly_allowsConfigAttributes() async throws {
    // ConfigAttributes is a Superwall-internal event, so it is permitted under
    // .superwallOnly — which is why the `eventTrackingBehavior` setter still
    // tracks it for .superwallOnly and only skips it for .none.
    let setup = makeQueue(behavior: .superwallOnly)

    await setup.queue.enqueue(
      data: stubJSON,
      from: InternalSuperwallEvent.ConfigAttributes(
        options: SuperwallOptions(),
        hasExternalPurchaseController: false,
        hasDelegate: false
      )
    )
    await setup.queue.flushInternal()
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(setup.network.sentEvents.count == 1)
  }

  // MARK: - EventTrackingBehavior.none

  @Test
  func none_blocksAllEvents() async throws {
    let setup = makeQueue(behavior: .none)

    await setup.queue.enqueue(data: stubJSON, from: InternalSuperwallEvent.AppOpen())
    await setup.queue.enqueue(
      data: stubJSON,
      from: InternalSuperwallEvent.UserAttributes(appInstalledAtString: "now")
    )
    await setup.queue.enqueue(
      data: stubJSON,
      from: UserInitiatedPlacement.Track(
        rawName: "test",
        canImplicitlyTriggerPaywall: false,
        isFeatureGatable: false
      )
    )
    await setup.queue.enqueue(
      data: stubJSON,
      from: InternalSuperwallEvent.TriggerFire(
        triggerResult: .noAudienceMatch([]),
        triggerName: "test"
      )
    )
    await setup.queue.flushInternal()
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(setup.network.sentEvents.isEmpty)
  }

  @Test
  func none_blocksConfigAttributes() async throws {
    // Backs up the `eventTrackingBehavior` setter's early return for .none: even
    // if a config-attributes event reached the queue (losing the Task-ordering
    // race), the queue still blocks it once the behavior is .none.
    let setup = makeQueue(behavior: .none)

    await setup.queue.enqueue(
      data: stubJSON,
      from: InternalSuperwallEvent.ConfigAttributes(
        options: SuperwallOptions(),
        hasExternalPurchaseController: false,
        hasDelegate: false
      )
    )
    await setup.queue.flushInternal()
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(setup.network.sentEvents.isEmpty)
  }

  @Test
  func superwallOnly_setTrackingBehaviorDiscardsBuffer() async throws {
    let setup = makeQueue(behavior: .all)
    await setup.queue.enqueue(data: stubJSON, from: InternalSuperwallEvent.AppOpen())
    await setup.queue.enqueue(data: stubJSON, from: InternalSuperwallEvent.AppOpen())

    await setup.queue.setTrackingBehavior(.superwallOnly)
    await setup.queue.flushInternal()
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(setup.network.sentEvents.isEmpty)
  }

  @Test
  func none_setTrackingBehaviorDiscardsBufferAndBlocksFlush() async throws {
    // Covers both the eager clear and the flush-time guard in one shot.
    let setup = makeQueue(behavior: .all)
    await setup.queue.enqueue(data: stubJSON, from: InternalSuperwallEvent.AppOpen())
    await setup.queue.enqueue(data: stubJSON, from: InternalSuperwallEvent.AppOpen())

    // Simulate the runtime opt-out (mirrors what Superwall.shared setter does).
    await setup.queue.setTrackingBehavior(.none)
    await setup.queue.flushInternal()
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(setup.network.sentEvents.isEmpty)
  }

  // MARK: - Deprecated isExternalDataCollectionEnabled backwards compatibility

  @Test
  func deprecatedFalse_mapsToSuperwallOnly() {
    let options = SuperwallOptions()
    options.isExternalDataCollectionEnabled = false
    #expect(options.eventTrackingBehavior == .superwallOnly)
  }

  @Test
  func deprecatedTrue_mapsToAll() {
    let options = SuperwallOptions()
    options.eventTrackingBehavior = .superwallOnly
    options.isExternalDataCollectionEnabled = true
    #expect(options.eventTrackingBehavior == .all)
  }

  @Test
  func deprecatedFalse_preservesNone() {
    let options = SuperwallOptions()
    options.eventTrackingBehavior = .none
    options.isExternalDataCollectionEnabled = false
    #expect(options.eventTrackingBehavior == .none)
  }

  @Test
  func deprecatedGetter_trueWhenAll() {
    let options = SuperwallOptions()
    options.eventTrackingBehavior = .all
    #expect(options.isExternalDataCollectionEnabled == true)
  }

  @Test
  func deprecatedGetter_falseWhenSuperwallOnly() {
    let options = SuperwallOptions()
    options.eventTrackingBehavior = .superwallOnly
    #expect(options.isExternalDataCollectionEnabled == false)
  }

  @Test
  func deprecatedGetter_falseWhenNone() {
    let options = SuperwallOptions()
    options.eventTrackingBehavior = .none
    #expect(options.isExternalDataCollectionEnabled == false)
  }

  // MARK: - Helpers

  private struct QueueSetup {
    let queue: PlacementsQueue
    let network: NetworkMock
    // Keep network and its dependencyContainer alive; network is the only unowned ref the queue holds.
    let configManager: ConfigManager
    let dependencyContainer: DependencyContainer
  }

  private func makeQueue(behavior: EventTrackingBehavior) -> QueueSetup {
    let options = SuperwallOptions()
    options.eventTrackingBehavior = behavior

    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(options: options, factory: dependencyContainer)
    let configManager = ConfigManager(
      options: options,
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    let queue = PlacementsQueue(network: network, configManager: configManager)
    return QueueSetup(
      queue: queue,
      network: network,
      configManager: configManager,
      dependencyContainer: dependencyContainer
    )
  }
}
