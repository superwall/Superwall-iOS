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

  // MARK: - Runtime Superwall.shared property

  @Test
  func runtimeSetter_updatesOptions() {
    Superwall.shared.eventTrackingBehavior = .superwallOnly
    #expect(Superwall.shared.options.eventTrackingBehavior == .superwallOnly)

    Superwall.shared.eventTrackingBehavior = .all
    #expect(Superwall.shared.options.eventTrackingBehavior == .all)
  }

  // MARK: - Helpers

  private struct QueueSetup {
    let queue: PlacementsQueue
    let network: NetworkMock
    let configManager: ConfigManager
    let dependencyContainer: DependencyContainer
  }

  private func makeQueue(behavior: EventTrackingBehavior) -> QueueSetup {
    Superwall.shared.options.eventTrackingBehavior = behavior

    let dependencyContainer = DependencyContainer()
    let network = NetworkMock(options: SuperwallOptions(), factory: dependencyContainer)
    let configManager = ConfigManager(
      options: SuperwallOptions(),
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
